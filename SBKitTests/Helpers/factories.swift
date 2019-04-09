import CoreData
@testable import SBKit

func chapterFactory(title: String = "Title", contentURL: URL = URL(string: "https://example.com")!, subchapters: [Chapter] = []) -> Chapter {
    return Chapter(title: title, contentURL: contentURL, subchapters: subchapters)
}

func subpage(named: String, of url: URL = URL(string: "https://example.com")!) -> URL {
    return url.appendingPathComponent(named, isDirectory: false)
}

func coreDataChapterFactory(objectContext: NSManagedObjectContext, book: CoreDataBook?, etag: String?, contentURL: URL, content: String?, title: String) -> CoreDataChapter {
    let chapter = NSEntityDescription.insertNewObject(forEntityName: "CoreDataChapter", into: objectContext) as! CoreDataChapter
    chapter.etag = etag
    chapter.contentURL = contentURL
    chapter.content = content
    chapter.title = title
    if let book = book {
        chapter.book = book
    }
    return chapter
}

let storeCoordinator: NSPersistentStoreCoordinator = {
    let store = try! persistentStoreCoordinatorFactory()
    try! addInMemoryStorage(to: store)
    return store
}()

func managedObjectContext() -> NSManagedObjectContext {
    let objectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    objectContext.persistentStoreCoordinator = storeCoordinator
    return objectContext
}

func resetStoreCoordinator() -> NSManagedObjectContext {
    let objectContext = managedObjectContext()

    objectContext.performAndWait {
        ["CoreDataBook", "CoreDataChapter"].forEach { entityName in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)

            let result = try! objectContext.fetch(fetchRequest)

            result.forEach {
                objectContext.delete($0)
            }

            try! objectContext.save()
        }
    }

    return objectContext
}
