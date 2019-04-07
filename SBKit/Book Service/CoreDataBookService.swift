import Result
import CoreData
import CBGPromise
import Foundation

enum CDError: Error {
    case noModelFound
    case unableToCreateModel
}

final class CoreDataBookService: BookService {
    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    private let syncService: SyncService
    private let queueJumper: OperationQueueJumper
    private let bookURL: URL

    private func managedObjectContext() -> NSManagedObjectContext {
        let objectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        objectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return objectContext
    }

    init(persistentStoreCoordinator: NSPersistentStoreCoordinator, syncService: SyncService, queueJumper: OperationQueueJumper, bookURL: URL) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.syncService = syncService
        self.queueJumper = queueJumper
        self.bookURL = bookURL
    }

    func chapters() -> Future<Result<[Chapter], ServiceError>> {
        return self.queueJumper.jump(self.book().map { (bookResult: Result<CoreDataBook, ServiceError>) -> Future<Result<[Chapter], ServiceError>> in
            switch bookResult {
            case .success(let book):
                return self.chapters(with: book)
            case .failure:
                return self.chaptersNoCache()
            }
        })
    }

    func title() -> Future<Result<String, ServiceError>> {
        return Promise<Result<String, ServiceError>>().future
    }

    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        return Promise<Result<String, ServiceError>>().future
    }

    private lazy var chapterURL: URL = { return bookURL.appendingPathComponent("api/chapters.json", isDirectory: false) }()
    private func chapters(with book: CoreDataBook) -> Future<Result<[Chapter], ServiceError>> {
        let existingChapters = self.chapters(of: book)
        let bookIdentifier: NSManagedObjectID = book.objectID

        // we already have chapter information cached. No matter what, return that data.

        return self.syncService.check(url: self.chapterURL, etag: book.etag!).map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                switch parseChapters(data: data, bookURL: self.bookURL) {
                case .success(let chapters):
                    return self.upsert(chapters: chapters, etag: etag, objectId: bookIdentifier)
                        .map {(result: Result<[Chapter], ServiceError>) -> Result<[Chapter], ServiceError> in
                            switch result {
                            case .success(let value):
                                return .success(value)
                            case .failure:
                                return .success(existingChapters)
                            }
                        }
                case .failure:
                    return Future<Result<[Chapter], ServiceError>>.resolved(.success(existingChapters))
                }
            case .success(.noNewContent), .failure:
                return Future<Result<[Chapter], ServiceError>>.resolved(.success(existingChapters))
            }
        }
    }

    private func chaptersNoCache() -> Future<Result<[Chapter], ServiceError>> {
        return self.syncService.check(url: self.chapterURL, etag: "").map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                return parseChapters(data: data, bookURL: self.bookURL).mapFuture { chapters in
                    return self.upsert(chapters: chapters, etag: etag, objectId: nil)
                }
            case .success(.noNewContent):
                return Future<Result<[Chapter], ServiceError>>.resolved(.failure(.cache))
            case .failure(let error):
                return Future<Result<[Chapter], ServiceError>>.resolved(.failure(error))
            }
        }
    }

    private func chapters(of book: CoreDataBook) -> [Chapter] {
        guard let chapters = book.chapters?.array as? [CoreDataChapter] else {
            return []
        }

        return chapters.map { $0.chapter() }
    }

    private func book() -> Future<Result<CoreDataBook, ServiceError>> {
        let promise = Promise<Result<CoreDataBook, ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CoreDataBook")
            let contents: [CoreDataBook]
            do {
                contents = try context.fetch(fetchRequest) as? [CoreDataBook] ?? []
            } catch let error {
                dump(error)
                promise.resolve(.failure(.cache))
                return
            }
            guard let book = contents.first(where: { $0.url == self.bookURL }) else {
                promise.resolve(.failure(.cache))
                return
            }
            promise.resolve(.success(book))
            return
        }
        return promise.future
    }

    private func upsert(chapters: [Chapter], etag: String, objectId: NSManagedObjectID?) -> Future<Result<[Chapter], ServiceError>> {
        let promise = Promise<Result<[Chapter], ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            let book: CoreDataBook
            if let objectIdentifier = objectId {
                book = context.object(with: objectIdentifier) as! CoreDataBook
            } else {
                book = CoreDataBook(context: context)
                context.insert(book)
            }
            book.etag = etag
            book.url = self.bookURL

            var existingChapters = Set(self.inlineCoreDataChapters(book: book, objectContext: context))
            for chapter in chapters {
                _ = self.upsert(chapter: chapter, context: context, book: book, isTopLevel: true, coreDataChapters: &existingChapters)
            }

            for unreferencedChapter in existingChapters {
                context.delete(unreferencedChapter)
            }

            do {
                try context.save()
            } catch let error {
                print("Unable to save: \(error)")
                promise.resolve(.failure(.cache))
                return
            }

            promise.resolve(.success(chapters))
        }
        return promise.future
    }

    private func inlineCoreDataChapters(book: CoreDataBook, objectContext: NSManagedObjectContext) -> [CoreDataChapter] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CoreDataChapter")
        fetchRequest.predicate = NSPredicate(format: "book == %@", book.objectID)
        return ((try? objectContext.fetch(fetchRequest)) ?? []) as? [CoreDataChapter] ?? []
    }

    private func upsert(chapter: Chapter, context: NSManagedObjectContext, book: CoreDataBook, isTopLevel: Bool, coreDataChapters: inout Set<CoreDataChapter>) -> CoreDataChapter? {
        var createdChapter: CoreDataChapter? = nil
        if let existingChapter = coreDataChapters.first(where: { $0.contentURL == chapter.contentURL }) {
            // update
            coreDataChapters.remove(existingChapter)
            existingChapter.content = nil
            existingChapter.title = chapter.title
        } else {
            let newChapter = CoreDataChapter(context: context)
            if isTopLevel {
                newChapter.book = book
            }
            newChapter.contentURL = chapter.contentURL
            newChapter.title = chapter.title
            newChapter.content = nil
            context.insert(newChapter)
            createdChapter = newChapter
        }

        for subchapter in chapter.subchapters {
            if let addedChapter = self.upsert(chapter: subchapter, context: context, book: book, isTopLevel: false, coreDataChapters: &coreDataChapters) {
                createdChapter?.addToSubchapters(addedChapter)
            }
        }

        return createdChapter
    }
}

extension CoreDataChapter {
    var subchaptersArray: [CoreDataChapter] {
        return self.subchapters?.array as? [CoreDataChapter] ?? []
    }

    func chapter() -> Chapter {
        return Chapter(title: self.title!, contentURL: self.contentURL!, subchapters: self.subchaptersArray.map { $0.chapter() })
    }
}

extension Future {
    class func resolved<T>(_ value: T) -> Future<T> {
        let promise = Promise<T>()
        promise.resolve(value)
        return promise.future
    }
}

extension Result where Result.Error: Swift.Error {
    public func mapFuture<U>(_ transform: (Value) -> Future<Result<U, Error>>) -> Future<Result<U, Error>> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return Future<Result<U, Error>>.resolved(Result<U, Error>.failure(error))
        }
    }
}

func persistentStoreCoordinatorFactory() throws -> NSPersistentStoreCoordinator {
    let bundle = Bundle(for: CoreDataBookService.self)
    guard let modelURL = bundle.url(forResource: "BookModel", withExtension: "momd") else {
        throw CDError.noModelFound
    }
    guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
        throw CDError.unableToCreateModel
    }
    let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    return persistentStoreCoordinator
}

func addSQLStorage(to persistentStoreCoordinator: NSPersistentStoreCoordinator, at fileName: String) throws {
    let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
    let fileURL = URL(string: "filename", relativeTo: dirURL)
    try persistentStoreCoordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: fileURL,
        options: nil
    )
}

func addInMemoryStorage(to persistentStoreCoordinator: NSPersistentStoreCoordinator) throws {
    try persistentStoreCoordinator.addPersistentStore(
        ofType: NSInMemoryStoreType,
        configurationName: nil,
        at: nil,
        options: nil
    )
}
