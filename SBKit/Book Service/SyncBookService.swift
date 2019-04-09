import Result
import CoreData
import CBGPromise
import Foundation

final class SyncBookService: BookService {
    private var operations: [Chapter: ChapterContentOperation] = [:]
    let bookService: BookService
    private let queueJumper: OperationQueueJumper
    private let operationQueue: OperationQueue

    init(bookService: BookService, operationQueue: OperationQueue, queueJumper: OperationQueueJumper) {
        self.bookService = bookService
        self.operationQueue = operationQueue
        self.queueJumper = queueJumper
    }

    func book() -> Future<Result<Book, ServiceError>> {
        return self.queueJumper.jump(self.bookService.book().then { (bookResult: Result<Book, ServiceError>) in
            guard let book = bookResult.value else { return }
            self.enqueue(chapters: book.flatChapters)
        })
    }

    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        let contentOperation: ChapterContentOperation
        if let operation = self.operations[chapter] {
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

    private func enqueue(chapters: [Chapter]) {
        let operations = chapters.map { ChapterContentOperation(bookService: self.bookService, chapter: $0) }

        operations.forEach {
            self.operations[$0.chapter] = $0
        }
        self.operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func addSingleOperation(chapter: Chapter) -> ChapterContentOperation {
        let contentOperation = ChapterContentOperation(bookService: self.bookService, chapter: chapter)
        self.operationQueue.addOperation(contentOperation)
        self.operations[chapter] = contentOperation
        return contentOperation
    }
}

final class ChapterContentOperation: Operation {
    private let promise = Promise<Result<String, ServiceError>>()
    private let bookService: BookService

    let chapter: Chapter

    var future: Future<Result<String, ServiceError>> {
        return self.promise.future
    }

    init(bookService: BookService, chapter: Chapter) {
        self.bookService = bookService
        self.chapter = chapter
        super.init()
    }

    override func start() {
        self.willChangeValue(forKey: "isExecuting")
        self.bookService.content(of: self.chapter).then {
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
