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

    func book() -> Future<Result<Book, ServiceError>> {
        return self.queueJumper.jump(self.book().map { (bookResult: Result<CoreDataBook, ServiceError>) -> Future<Result<Book, ServiceError>> in
            switch bookResult {
            case .success(let book):
                return self.book(with: book)
            case .failure:
                return self.bookNoCache()
            }
        })
    }

    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        return self.queueJumper.jump(self.chapter(from: chapter).map { (chapterResult: Result<CoreDataChapter, ServiceError>) -> Future<Result<String, ServiceError>> in
            switch chapterResult {
            case .success(let coreDataChapter):
                if let etag = coreDataChapter.etag {
                    return self.chapterContent(url: chapter.contentURL, etag: etag, objectIdentifier: coreDataChapter.objectID)
                } else {
                    return self.chapterContentNoCache(url: chapter.contentURL, objectIdentifier: coreDataChapter.objectID)
                }
            case .failure(let error):
                return Future<Result<String, ServiceError>>.resolved(.failure(error))
            }
        })
    }

    // MARK: Getting Book
    private lazy var bookAPIURL: URL = { return bookURL.appendingPathComponent("api/book.json", isDirectory: false) }()
    private func book(with book: CoreDataBook) -> Future<Result<Book, ServiceError>> {
        guard let etag = book.etag else {
            return self.bookNoCache()
        }
        let bookIdentifier: NSManagedObjectID = book.objectID

        let getExistingBook: () -> Future<Result<Book, ServiceError>> = {
            return self.object(with: bookIdentifier).map { (result: Result<CoreDataBook, ServiceError>) -> Result<Book, ServiceError> in
                return result.map { cdBook in
                    return cdBook.book()
                }
            }
        }

        // we already have chapter information cached. No matter what, return that data.

        return self.syncService.check(url: self.bookAPIURL, etag: etag).map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                switch parseBook(data: data, bookURL: self.bookURL) {
                case .success(let book):
                    return self.upsert(book: book, etag: etag, objectId: bookIdentifier)
                        .map {(result: Result<Book, ServiceError>) -> Future<Result<Book, ServiceError>> in
                            switch result {
                            case .success(let value):
                                return Future<Result<[Chapter], ServiceError>>.resolved(.success(value))
                            case .failure:
                                return getExistingBook()
                            }
                        }
                case .failure:
                    return getExistingBook()
                }
            case .success(.noNewContent), .failure:
                return getExistingBook()
            }
        }
    }

    private func bookNoCache() -> Future<Result<Book, ServiceError>> {
        return self.syncService.check(url: self.bookAPIURL, etag: "").map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                return parseBook(data: data, bookURL: self.bookURL).mapFuture { book in
                    return self.upsert(book: book, etag: etag, objectId: nil)
                }
            case .success(.noNewContent):
                return Future<Result<[Chapter], ServiceError>>.resolved(.failure(.cache))
            case .failure(let error):
                return Future<Result<[Chapter], ServiceError>>.resolved(.failure(error))
            }
        }
    }

    private func book() -> Future<Result<CoreDataBook, ServiceError>> {
        let promise = Promise<Result<CoreDataBook, ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CoreDataBook")
            fetchRequest.predicate = NSPredicate(format: "url.absoluteString = %@", self.bookURL.absoluteString)
            fetchRequest.fetchLimit = 1
            let coreDataBook: CoreDataBook?
            do {
                coreDataBook = try context.fetch(fetchRequest).first as? CoreDataBook
            } catch let error {
                dump(error)
                promise.resolve(.failure(.cache))
                return
            }
            guard let book = coreDataBook else {
                promise.resolve(.failure(.cache))
                return
            }
            promise.resolve(.success(book))
            return
        }
        return promise.future
    }

    private func object<T: NSManagedObject>(with id: NSManagedObjectID) -> Future<Result<T, ServiceError>> {
        let promise = Promise<Result<T, ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            guard let object = context.object(with: id) as? T else {
                promise.resolve(.failure(.cache))
                return
            }
            promise.resolve(.success(object))
        }
        return promise.future
    }

    private func upsert(book: Book, etag: String, objectId: NSManagedObjectID?) -> Future<Result<Book, ServiceError>> {
        let promise = Promise<Result<Book, ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            let cdBook: CoreDataBook
            if let objectIdentifier = objectId {
                cdBook = context.object(with: objectIdentifier) as! CoreDataBook
            } else {
                cdBook = CoreDataBook(context: context)
                context.insert(cdBook)
            }
            cdBook.etag = etag
            cdBook.url = self.bookURL
            cdBook.title = book.title

            var existingChapters = Set(self.inlineCoreDataChapters(book: cdBook, objectContext: context))
            for chapter in book.chapters {
                _ = self.upsert(chapter: chapter, context: context, book: cdBook, isTopLevel: true, coreDataChapters: &existingChapters)
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

            promise.resolve(.success(book))
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
        let upsertedChapter: CoreDataChapter
        if let existingChapter = coreDataChapters.first(where: { $0.contentURL == chapter.contentURL }) {
            // update
            coreDataChapters.remove(existingChapter)
            existingChapter.title = chapter.title
            upsertedChapter = existingChapter
        } else {
            let newChapter = NSEntityDescription.insertNewObject(forEntityName: "CoreDataChapter", into: context) as! CoreDataChapter
            if isTopLevel {
                newChapter.book = book
            }
            newChapter.contentURL = chapter.contentURL
            newChapter.title = chapter.title
            newChapter.content = nil
            context.insert(newChapter)
            createdChapter = newChapter
            upsertedChapter = newChapter
        }

        for subchapter in chapter.subchapters {
            if let addedChapter = self.upsert(chapter: subchapter, context: context, book: book, isTopLevel: false, coreDataChapters: &coreDataChapters) {
                upsertedChapter.addToSubchapters(addedChapter)
            }
        }

        return createdChapter
    }

    // MARK: Getting Chapter Content
    private func chapter(from chapter: Chapter) -> Future<Result<CoreDataChapter, ServiceError>> {
        let promise = Promise<Result<CoreDataChapter, ServiceError>>()
        let context = self.managedObjectContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CoreDataChapter")
            fetchRequest.predicate = NSPredicate(format: "contentURL.absoluteString = %@", chapter.contentURL.absoluteString)
            fetchRequest.fetchLimit = 1
            let coreDataChapter: CoreDataChapter?
            do {
                coreDataChapter = try context.fetch(fetchRequest).first as? CoreDataChapter
            } catch let error {
                dump(error)
                promise.resolve(.failure(.cache))
                return
            }
            guard let cdChapter = coreDataChapter else {
                promise.resolve(.failure(.cache))
                return
            }
            promise.resolve(.success(cdChapter))
            return
        }
        return promise.future
    }

    private func chapterContent(url: URL, etag originalEtag: String, objectIdentifier: NSManagedObjectID) -> Future<Result<String, ServiceError>> {
        let getExistingContent: () -> Future<Result<String, ServiceError>> = {
            return self.object(with: objectIdentifier).map { (result: Result<CoreDataChapter, ServiceError>) -> Result<String, ServiceError> in
                return result.flatMap {
                    guard let content = $0.content else {
                        return .failure(.cache)
                    }
                    return .success(content)
                }
            }
        }

        return self.syncService.check(url: url, etag: originalEtag).map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                switch parseChapterContent(data: data, url: url) {
                case .success(let html):
                    return self.upsert(content: html, etag: etag, objectId: objectIdentifier)
                case .failure(let error):
                    return Future<Result<String, ServiceError>>.resolved(.failure(error))
                }
            case .success(.noNewContent), .failure:
                return getExistingContent()
            }
        }
    }

    private func chapterContentNoCache(url: URL, objectIdentifier: NSManagedObjectID) -> Future<Result<String, ServiceError>> {
        return self.syncService.check(url: url, etag: "").map { (syncResult: Result<SyncJudgement, ServiceError>) in
            switch syncResult {
            case .success(.updateAvailable(content: let data, etag: let etag)):
                switch parseChapterContent(data: data, url: url) {
                case .success(let html):
                    return self.upsert(content: html, etag: etag, objectId: objectIdentifier)
                case .failure(let error):
                    return Future<Result<String, ServiceError>>.resolved(.failure(error))
                }
            case .success(.noNewContent):
                return Future<Result<String, ServiceError>>.resolved(.failure(.cache))
            case .failure(let error):
                return Future<Result<String, ServiceError>>.resolved(.failure(error))
            }
        }
    }

    private func upsert(content: String, etag: String, objectId: NSManagedObjectID) -> Future<Result<String, ServiceError>> {
        let promise = Promise<Result<String, ServiceError>>()
        let context = self.managedObjectContext()

        context.perform {
            guard let chapter = context.object(with: objectId) as? CoreDataChapter else {
                promise.resolve(.failure(.cache))
                return
            }
            chapter.etag = etag
            chapter.content = content

            do {
                try context.save()
            } catch let error {
                print("Unable to save: \(error)")
                promise.resolve(.failure(.cache))
                return
            }

            promise.resolve(.success(content))
        }
        return promise.future
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

extension CoreDataBook {
    func book() -> Book {
        return Book(
            title: self.title!,
            chapters: (self.chapters!.array as! [CoreDataChapter]).map { $0.chapter() }
        )
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
    let fileURL = URL(string: fileName, relativeTo: dirURL)
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
