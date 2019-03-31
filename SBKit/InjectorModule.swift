import Swinject

public func register(_ container: Container) {
    let mainQueue = "MainQueue"

    container.register(OperationQueue.self, name: mainQueue) { _ in
        return OperationQueue.main
    }

    container.register(OperationQueueJumper.self) { r in
        return OperationQueueJumper(queue: r.resolve(OperationQueue.self, name: mainQueue)!)
    }

    container.register(BookService.self) { r, url in
        return NetworkBookService(
            client: URLSession.shared,
            queueJumper: r.resolve(OperationQueueJumper.self)!,
            bookURL: url
        )
    }
}
