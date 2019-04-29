import Quick
import Nimble
import XCTest
import Result
import CBGPromise
import Foundation

@testable import SBKit

final class CoreDataBookServiceSpec: QuickSpec {
    override func spec() {
        var subject: CoreDataBookService!

        let coordinator = try! persistentStoreCoordinatorFactory()
        do {
            try addInMemoryStorage(to: coordinator)
//            try addSQLStorage(to: coordinator, at: "BookModel")
        } catch let error {
            dump(error)
        }

        let bookURL = URL(string: "https://knowledge.rachelbrindle.com")!

        let timeout: TimeInterval = 30
        let amountToRepeat = 20

        beforeEach {
            let syncService = NetworkSyncService(
                httpClient: URLSession.shared
            )

            subject = CoreDataBookService(
                persistentStoreCoordinator: coordinator,
                syncService: syncService,
                queueJumper: OperationQueueJumper(queue: .main),
                bookURL: bookURL
            )
        }

        describe("Fetching a book") {
            func fetchBookSynchronously(expectation: XCTestExpectation?) {
                subject.book().then { result in
                    expect(result.value).toNot(beNil())
                    expectation?.fulfill()
                }
            }

            it("doesn't crash when you fetch a book multiple times in succession") {
                (0..<amountToRepeat).forEach { _ in fetchBookSynchronously(expectation: nil) }
            }

            it("doesn't crash when you fetch a book multiple times concurrently") {
                let operations = (0..<amountToRepeat).map { (index: Int) -> BlockOperation in
                    let expectation = self.expectation(description: "Fetch Book request #\(index)")
                    return BlockOperation {
                        fetchBookSynchronously(expectation: expectation)
                    }
                }
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = amountToRepeat / 5
                queue.qualityOfService = .userInitiated
                queue.addOperations(operations, waitUntilFinished: true)

                self.waitForExpectations(timeout: timeout, handler: nil)
            }
        }

        describe("fetching chapter content") {
            var chapters: [Chapter] = []

            beforeEach {
                let future = subject.book()

                expect(future.value).toEventuallyNot(beNil(), timeout: timeout, description: "Expected future to get resolved")
                expect(future.value?.value).toNot(beNil())

                guard let book = future.value?.value else { return }

                chapters = book.flatChapters
            }

            func fetchChapterContent(chapter: Chapter, expectation: XCTestExpectation?) {
                subject.content(of: chapter).then { result in
                    expect(result.value).toNot(beNil())
                    expectation?.fulfill()
                }
            }

            it("doesn't crash when you fetch chapter content multiple times in succession") {
                guard let chapter = chapters.last else {
                    fail("No chapters available to fetch")
                    return
                }

                (0..<amountToRepeat).forEach { _ in
                    fetchChapterContent(chapter: chapter, expectation: nil)
                }
            }

            it("doesn't crash when you fetch chapter content multiple times concurrently") {
                guard let chapter = chapters.last else {
                    fail("No chapters available to fetch")
                    return
                }

                let operations = (0..<amountToRepeat).map { (index: Int) -> BlockOperation in
                    let expectation = self.expectation(description: "Fetch Book request #\(index)")
                    return BlockOperation {
                        fetchChapterContent(chapter: chapter, expectation: expectation)
                    }
                }
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = amountToRepeat / 5
                queue.qualityOfService = .userInitiated
                queue.addOperations(operations, waitUntilFinished: true)

                self.waitForExpectations(timeout: timeout, handler: nil)
            }
        }
    }
}
