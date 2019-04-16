import CoreData
import Swinject
import FutureHTTP

public func register(_ container: Container) {
    let mainQueue = "MainQueue"

    container.register(OperationQueue.self, name: mainQueue) { _ in
        return OperationQueue.main
    }

    container.register(HTTPClient.self) { _ in return URLSession.shared }

    container.register(OperationQueueJumper.self) { r in
        return OperationQueueJumper(queue: r.resolve(OperationQueue.self, name: mainQueue)!)
    }

    container.register(ActivityService.self) { _ in
        return SearchActivityService()
    }.inObjectScope(.container)

    registerSync(container)
}

private func registerSync(_ container: Container) {
    container.register(NSPersistentStoreCoordinator.self) { _ in
        let coordinator = try! persistentStoreCoordinatorFactory()
        try! addSQLStorage(to: coordinator, at: "BookModel")
        return coordinator
    }.inObjectScope(.container)

    container.register(SyncService.self) { r in
        return NetworkSyncService(httpClient: r.resolve(HTTPClient.self)!)
    }

    container.register(BookService.self) { (r: Resolver, url: URL) in
        let cdBookService = CoreDataBookService(
            persistentStoreCoordinator: r.resolve(NSPersistentStoreCoordinator.self)!,
            syncService: r.resolve(SyncService.self)!,
            queueJumper: r.resolve(OperationQueueJumper.self)!,
            bookURL: url
        )

        let workQueue = OperationQueue()
        workQueue.maxConcurrentOperationCount = 3
        workQueue.qualityOfService = QualityOfService.background

        return SyncBookService(
            bookService: cdBookService,
            operationQueue: workQueue,
            queueJumper: r.resolve(OperationQueueJumper.self)!
        )
    }.inObjectScope(.container)
}
