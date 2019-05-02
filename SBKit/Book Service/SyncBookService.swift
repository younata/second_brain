import Result
import CoreData
import CBGPromise
import Foundation

final class SyncBookService: BookService {
    private var operations: [Chapter: ChapterContentOperation] = [:]

    let bookService: BookService
    private let searchIndexService: SearchIndexService
    private let queueJumper: OperationQueueJumper
    private let operationQueue: OperationQueue
    private let notificationPoster: NotificationPoster
    private let dateOracle: () -> Date

    private let chapterOperationQueue = DispatchQueue(label: "SyncBookService Chapter Operation Syncing Queue")

    init(bookService: BookService, searchIndexService: SearchIndexService, operationQueue: OperationQueue,
         queueJumper: OperationQueueJumper, notificationPoster: NotificationPoster, dateOracle: @escaping () -> Date) {
        self.bookService = bookService
        self.searchIndexService = searchIndexService
        self.operationQueue = operationQueue
        self.queueJumper = queueJumper
        self.notificationPoster = notificationPoster
        self.dateOracle = dateOracle
    }

    private var lastFetchedDate: Date?
    private var bookFuture: Future<Result<Book, ServiceError>>?
    func book() -> Future<Result<Book, ServiceError>> {
        let future: Future<Result<Book, ServiceError>>
        if shouldRefetch() {
            future = self.fetchBook()
        } else if let existingBookFuture = self.bookFuture {
            future = existingBookFuture
        } else {
            future = self.fetchBook() // Can't happen, but still.
        }
        self.bookFuture = future
        return self.queueJumper.jump(future)
    }

    private func shouldRefetch() -> Bool {
        guard let future = self.bookFuture else {
            // If we haven't fetched in the first place, then of course we should fetch!
            return true
        }
        switch future.value {
        case .failure?:
            return true // Always refetch if we most recently got an error.
        case .none:
            return false // Never refetch if we're in the middle if a fetch.
        case .success?:
            // Only refetch if it's been more than a minute since we last fetched.
            guard let previousDate = self.lastFetchedDate else { return false }
            let interval = self.dateOracle().timeIntervalSince(previousDate)
            return interval > 60
        }
    }

    private func fetchBook() -> Future<Result<Book, ServiceError>> {
        let promise = Promise<Result<Book, ServiceError>>()
        self.bookService.book().then { (bookResult: Result<Book, ServiceError>) in
            self.lastFetchedDate = self.dateOracle()
            let errorMessage: String?
            let totalAmount: Int
            switch bookResult {
            case .failure(let error):
                totalAmount = 1
                errorMessage = error.localizedDescription
                promise.resolve(bookResult)
            case .success(let book):
                totalAmount = 1 + book.flatChapters.count
                errorMessage = nil
                self.enqueue(chapters: book.flatChapters, promise: promise, book: book)
            }
            let note = BookServiceNotification(
                total: totalAmount,
                completed: 1,
                errorMessage: errorMessage
            )
            self.notificationPoster.post(notification: note.bookNotification())
        }
        return promise.future
    }

    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        let contentOperation: ChapterContentOperation
        let existingOperation: ChapterContentOperation? = self.chapterOperationQueue.sync {
            return self.operations[chapter]
        }
        if let operation = existingOperation {
            if operation.future.value?.error != nil {
                contentOperation = self.addSingleOperation(chapter: chapter)
            } else {
                contentOperation = operation
            }
        } else {
            contentOperation = self.addSingleOperation(chapter: chapter)
        }
        if !contentOperation.isFinished {
            contentOperation.qualityOfService = .userInitiated
            contentOperation.queuePriority = Operation.QueuePriority.veryHigh
        }
        return self.queueJumper.jump(contentOperation.future)
    }

    private func enqueue(chapters: [Chapter], promise: Promise<Result<Book, ServiceError>>, book: Book) {
        let operations = chapters.map { self.createOperation(for: $0) }
        let totalCount = chapters.count + 1
        operations.enumerated().forEach { index, operation in
            let chapterNumber = index + 2
            operation.future.then { (result: Result<String, ServiceError>) in
                let notification = BookServiceNotification(
                    total: totalCount,
                    completed: chapterNumber,
                    errorMessage: result.error?.localizedDescription
                )
                self.notificationPoster.post(notification: notification.chapterNotification())
            }
        }

        let updateSearchOperation = BlockOperation {
            self.searchIndexService.endRefresh()
            promise.resolve(.success(book))
        }
        self.chapterOperationQueue.sync {
            operations.forEach {
                self.operations[$0.chapter] = $0
                updateSearchOperation.addDependency($0)
            }
        }

        self.operationQueue.addOperations(operations, waitUntilFinished: false)
        self.operationQueue.addOperation(updateSearchOperation)
    }

    private func addSingleOperation(chapter: Chapter) -> ChapterContentOperation {
        let contentOperation = self.createOperation(for: chapter)
        self.operationQueue.addOperation(contentOperation)
        self.chapterOperationQueue.sync {
            self.operations[chapter] = contentOperation
        }
        return contentOperation
    }

    private func createOperation(for chapter: Chapter) -> ChapterContentOperation {
        let operation = ChapterContentOperation(bookService: self.bookService, searchIndexService: self.searchIndexService, chapter: chapter)
        operation.future.then { _ in
            self.chapterOperationQueue.sync {
                self.operations.removeValue(forKey: chapter)
            }
        }
        return operation
    }
}

final class ChapterContentOperation: Operation {
    private let promise = Promise<Result<String, ServiceError>>()
    private let bookService: BookService
    private let searchIndexService: SearchIndexService

    let chapter: Chapter

    var future: Future<Result<String, ServiceError>> {
        return self.promise.future
    }

    init(bookService: BookService, searchIndexService: SearchIndexService, chapter: Chapter) {
        self.bookService = bookService
        self.searchIndexService = searchIndexService
        self.chapter = chapter
        super.init()
    }

    override func start() {
        self.willChangeValue(forKey: "isExecuting")
        self.bookService.content(of: self.chapter).then {
            if let content = $0.value {
                self.searchIndexService.update(chapter: self.chapter, content: content)
            }

            self.willChangeValue(forKey: "isExecuting")
            defer {
                self._isExecuting = false
                self.didChangeValue(forKey: "isExecuting")
            }
            guard self.future.value == nil else { return }
            self.willChangeValue(forKey: "isFinished")
            self.promise.resolve($0)
            self.didChangeValue(forKey: "isFinished")
        }
        self._isExecuting = true
        self.didChangeValue(forKey: "isExecuting")
    }

    override var isAsynchronous: Bool { return true }

    private var _isExecuting: Bool = false
    override var isExecuting: Bool { return !self.isFinished && self._isExecuting }
    override var isFinished: Bool { return self.future.value != nil }
}
