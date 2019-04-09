import Quick
import Nimble
import Result
import CBGPromise
import Foundation_PivotalSpecHelper

@testable import SBKit

final class SyncBookServiceSpec: QuickSpec {
    override func spec() {
        var subject: SyncBookService!
        var queueJumper: OperationQueueJumper!
        var mainQueue: PSHKFakeOperationQueue!

        var workQueue: PSHKFakeOperationQueue!

        var bookService: FakeBookService!

        beforeEach {
            bookService = FakeBookService()

            workQueue = PSHKFakeOperationQueue()

            mainQueue = PSHKFakeOperationQueue()
            queueJumper = OperationQueueJumper(queue: mainQueue)

            subject = SyncBookService(
                bookService: bookService,
                operationQueue: workQueue,
                queueJumper: queueJumper
            )
        }

        describe("book()") {
            var future: Future<Result<Book, ServiceError>>!

            beforeEach {
                future = subject.book()
            }

            it("asks the underlying book service for the book") {
                expect(bookService.bookPromises).to(haveCount(1))
            }

            describe("when the book promise succeeds") {
                let chapters: [Chapter] = [
                    Chapter(title: "chapter 1", contentURL: URL(string: "https://example.com/1.html")!, subchapters: [
                        Chapter(title: "chapter 1.1", contentURL: URL(string: "https://example.com/1.1.html")!, subchapters: []),
                    ]),
                    Chapter(title: "chapter 2", contentURL: URL(string: "https://example.com/2.html")!, subchapters: []),
                ]

                let book = Book(
                    title: "My Title",
                    chapters: chapters
                )

                beforeEach {
                    bookService.bookPromises.last?.resolve(.success(book))
                }

                it("resolves the future with the book, after jumping to the main queue") {
                    expect(future.value).to(beNil())

                    expect(mainQueue.operationCount).to(equal(1))
                    guard mainQueue.operationCount == 1 else { return }
                    mainQueue.runNextOperation()

                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(equal(book))
                }

                it("queues up an on the workQueue for each chapter in the book") {
                    expect(workQueue.operationCount).to(equal(3))
                    expect(workQueue.operations.compactMap { $0 as? ChapterContentOperation }).to(haveCount(3))

                    for operation in workQueue.operations {
                        expect(operation.queuePriority).to(equal(.normal))
                        expect(operation.qualityOfService).to(equal(.default))
                    }
                }
            }

            describe("when the book promise fails") {
                beforeEach {
                    bookService.bookPromises.last?.resolve(.failure(.unknown))
                }

                it("resolves the future with the failure") {
                    expect(future.value).to(beNil())

                    expect(mainQueue.operationCount).to(equal(1))
                    guard mainQueue.operationCount == 1 else { return }
                    mainQueue.runNextOperation()

                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(equal(.unknown))
                }

                it("does not add anything to the workQueue") {
                    expect(workQueue.operationCount).to(equal(0))
                }
            }
        }

        describe("content(of chapter:)") {
            let chapter = Chapter(title: "Chapter 1", contentURL: URL(string: "https://example.com/1.html")!, subchapters: [])

            var future: Future<Result<String, ServiceError>>!

            func itRunsTheOperation() {
                describe("when the operation runs") {
                    describe("when the operation succeeds") {
                        beforeEach {
                            DispatchQueue.global().async {
                                workQueue.runNextOperation()
                            }
                            expect(bookService.contentsPromises).toEventually(haveCount(1))
                            bookService.contentsPromises.last?.resolve(.success("Content"))
                        }

                        it("resolves the future... on the main thread") {
                            expect(future.value).to(beNil())

                            expect(mainQueue.operationCount).to(equal(1))
                            guard mainQueue.operationCount == 1 else { return }
                            mainQueue.runNextOperation()

                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                            expect(future.value?.value).to(equal("Content"))
                        }
                    }

                    describe("when the operation fails") {
                        beforeEach {
                            DispatchQueue.global().async {
                                workQueue.runNextOperation()
                            }
                            expect(bookService.contentsPromises).toEventually(haveCount(1))
                            bookService.contentsPromises.last?.resolve(.failure(.cache))
                        }

                        it("resolves the future... on the main thread") {
                            expect(future.value).to(beNil())

                            expect(mainQueue.operationCount).to(equal(1))
                            guard mainQueue.operationCount == 1 else { return }
                            mainQueue.runNextOperation()

                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                            expect(future.value?.error).to(equal(.cache))
                        }
                    }
                }
            }

            context("when there was a previously queue'd up operation to get this chapter's content") {
                beforeEach {
                    _ = subject.book()
                    bookService.bookPromises.last?.resolve(.success(Book(title: "", chapters: [chapter])))
                    mainQueue.runNextOperation()

                    expect(workQueue.operationCount).to(equal(1))
                }

                context("and that operation had completed") {
                    context("successfully") {
                        beforeEach {
                            DispatchQueue.global().async {
                                workQueue.runNextOperation()
                            }
                            expect(bookService.contentsPromises).toEventually(haveCount(1))
                            bookService.contentsPromises.last?.resolve(.success("Content"))

                            future = subject.content(of: chapter)
                        }

                        it("resolves the future on the main thread") {
                            expect(future.value).to(beNil())

                            expect(mainQueue.operationCount).to(equal(1))
                            guard mainQueue.operationCount == 1 else { return }
                            mainQueue.runNextOperation()

                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                            expect(future.value?.value).to(equal("Content"))
                        }
                    }

                    context("unsuccessfully") {
                        beforeEach {
                            expect(bookService.contentsPromises).to(haveCount(0))
                            DispatchQueue.global().async {
                                workQueue.runNextOperation()
                            }
                            expect(bookService.contentsPromises).toEventually(haveCount(1))
                            bookService.contentsPromises.last?.resolve(.failure(.cache))

                            expect(workQueue.operations).toEventually(beEmpty())

                            bookService.resetContents()

                            future = subject.content(of: chapter)
                        }

                        it("adds another operation to the work queue requesting the content, at a very high priority") {
                            expect(workQueue.operations).to(haveCount(1))

                            guard let operation = workQueue.operations.last else { return }
                            expect(operation.queuePriority).to(equal(.veryHigh))
                            expect(operation.qualityOfService).to(equal(.userInitiated))
                        }

                        itRunsTheOperation()
                    }
                }

                context("and that operation hadn't ran yet") {
                    beforeEach {
                        future = subject.content(of: chapter)
                    }

                    it("ups the priority of the operations, now that the user is actually waiting on it") {
                        expect(workQueue.operations).to(haveCount(1))

                        guard let operation = workQueue.operations.last else { return }
                        expect(operation.queuePriority).to(equal(.veryHigh))
                        expect(operation.qualityOfService).to(equal(.userInitiated))
                    }

                    itRunsTheOperation()
                }
            }

            context("when there wasn't a previously queue'd up operation to get this chapter's content") {
                beforeEach {
                    expect(workQueue.operations).to(beEmpty())

                    future = subject.content(of: chapter)
                }

                it("adds another operation to the work queue requesting the content, at a very high priority") {
                    expect(workQueue.operations).to(haveCount(1))

                    guard let operation = workQueue.operations.last else { return }
                    expect(operation.queuePriority).to(equal(.veryHigh))
                    expect(operation.qualityOfService).to(equal(.userInitiated))
                }

                itRunsTheOperation()
            }
        }
    }
}
