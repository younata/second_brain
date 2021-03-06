import Quick
import Nimble
import Result
import CoreData
import CBGPromise
import FutureHTTP
import Foundation_PivotalSpecHelper

@testable import SBKit

final class CoreDataBookServiceSpec: QuickSpec {
    override func spec() {
        var subject: CoreDataBookService!

        var objectContext: NSManagedObjectContext!
        var syncService: FakeSyncService!
        var queueJumper: OperationQueueJumper!

        var delegate: FakeBookServiceDelegate!

        let bookURL = URL(string: "https://example.com")!

        beforeEach {
            objectContext = resetStoreCoordinator()

            syncService = FakeSyncService()

            queueJumper = OperationQueueJumper(queue: .main)

            subject = CoreDataBookService(
                persistentStoreCoordinator: storeCoordinator,
                syncService: syncService,
                queueJumper: queueJumper,
                bookURL: bookURL
            )

            delegate = FakeBookServiceDelegate()
            subject.delegate = delegate
        }

        describe("-Book()") {
            var future: Future<Result<Book, ServiceError>>!

            var cdbook: CoreDataBook?
            var cdchapters: [CoreDataChapter] = []

            func itBehavesLikeNewDataWasReturned(delegateExpect: @escaping () -> Void) {
                describe("when the sync service comes back with new data") {
                    let chapters: [String: Any] = [
                        "title": "new title",
                        "chapters": [
                            ["path": "/index.html", "title": "Introduction", "subchapters": []],
                            ["path": "/ci/index.html", "title": "Continuous Integration", "subchapters": [
                                ["path": "/ci/concourse.html", "title": "Concourse", "subchapters": []]
                                ]],
                            ["path": "/food/index.html", "title": "Food", "subchapters": [
                                ["path": "/food/recipes/index.html", "title": "Recipes", "subchapters": [
                                    ["path": "/food/recipes/mac_and_cheese.html", "title": "Mac and Cheese", "subchapters": []],
                                    ["path": "/food/recipes/soup.html", "title": "Simple Soup", "subchapters": []]
                                    ]]
                                ]]
                        ]]
                    beforeEach {
                        guard let jsonChapters = try? JSONSerialization.data(withJSONObject: chapters, options: []) else {
                            fail("Unable to serialize chapters")
                            return
                        }
                        syncService.checkPromises.last?.resolve(.success(.updateAvailable(content: jsonChapters, etag: "new_chapters")))
                    }

                    it("resolves the future with the parsed chapters") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal(Book(
                            title: "new title",
                            chapters: [
                                Chapter(title: "Introduction", contentURL: subpage(named: "index.html"), subchapters: []),
                                Chapter(title: "Continuous Integration", contentURL: subpage(named: "ci/index.html"), subchapters: [
                                    Chapter(title: "Concourse", contentURL: subpage(named: "ci/concourse.html"), subchapters: [])
                                    ]),
                                Chapter(title: "Food", contentURL: subpage(named: "food/index.html"), subchapters: [
                                    Chapter(title: "Recipes", contentURL: subpage(named: "food/recipes/index.html"), subchapters: [
                                        Chapter(title: "Mac and Cheese", contentURL: subpage(named: "food/recipes/mac_and_cheese.html"), subchapters: []),
                                        Chapter(title: "Simple Soup", contentURL: subpage(named: "food/recipes/soup.html"), subchapters: []),
                                        ])
                                    ])
                            ])))
                    }

                    it("updates the stored book and chapters") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        objectContext.performAndWait {
                            objectContext.refreshAllObjects()
                            let results = (try! objectContext.fetch(NSFetchRequest(entityName: "CoreDataBook")))
                            expect(results).to(haveCount(1))
                            cdbook = results.first as? CoreDataBook
                            cdchapters = cdbook?.chapters?.array as? [CoreDataChapter] ?? []
                        }

                        expect(cdbook?.etag).to(equal("new_chapters"))
                        expect(cdbook?.url).to(equal(bookURL))
                        expect(cdbook?.title).to(equal("new title"))

                        expect(cdchapters.count).to(equal(3))

                        guard cdchapters.count == 3 else { return }
                        // Chapter 1
                        assertCoreDataChapter(chapter: cdchapters[0], book: cdbook, url: subpage(named: "index.html"),
                                              title: "Introduction", etag: nil, content: nil)
                        expect(cdchapters[0].subchapters).to(beEmpty())

                        // Chapter 2
                        assertCoreDataChapter(chapter: cdchapters[1], book: cdbook,
                                              url: subpage(named: "ci/index.html"), title: "Continuous Integration",
                                              etag: nil, content: nil)
                        expect(cdchapters[1].subchapters?.array).to(haveCount(1))
                        guard cdchapters[1].subchapters?.count == 1 else { return }
                        // Chapter 2.1
                        assertCoreDataChapter(chapter: (cdchapters[1].subchapters!.array as! [CoreDataChapter])[0],
                                              book: nil, url: subpage(named: "ci/concourse.html"),
                                              title: "Concourse", etag: nil, content: nil)
                        expect((cdchapters[1].subchapters!.array as! [CoreDataChapter])[0].subchapters).to(beEmpty())

                        // Chapter 3
                        assertCoreDataChapter(chapter: cdchapters[2], book: cdbook,
                                              url: subpage(named: "food/index.html"), title: "Food", etag: nil,
                                              content: nil)
                        expect(cdchapters[2].subchapters!.array).to(haveCount(1))

                        // Chapter 3.1
                        guard let foodSubchapter = cdchapters[2].subchapters!.firstObject as? CoreDataChapter else { return }
                        assertCoreDataChapter(chapter: foodSubchapter, book: nil,
                                              url: subpage(named: "food/recipes/index.html"), title: "Recipes",
                                              etag: nil, content: nil)
                        expect(foodSubchapter.subchapters!.array).to(haveCount(2))

                        // Chapter 3.1.1
                        guard let recipesSubchapter1 = foodSubchapter.subchapters!.firstObject as? CoreDataChapter else { return }
                        assertCoreDataChapter(chapter: recipesSubchapter1, book: nil,
                                              url: subpage(named: "food/recipes/mac_and_cheese.html"), title: "Mac and Cheese",
                                              etag: nil, content: nil)

                        // Chapter 3.1.2
                        guard let recipesSubchapter2 = foodSubchapter.subchapters!.lastObject as? CoreDataChapter else { return }
                        assertCoreDataChapter(chapter: recipesSubchapter2, book: nil,
                                              url: subpage(named: "food/recipes/soup.html"), title: "Simple Soup",
                                              etag: nil, content: nil)

                        // Any other CoreDataChapters are removed.
                        objectContext.performAndWait {
                            let results = try! objectContext.fetch(NSFetchRequest(entityName: "CoreDataChapter"))
                            expect(results).to(haveCount(7))
                            expect(results as? [CoreDataChapter]).to(haveCount(7))
                        }
                    }

                    delegateExpect()
                }
            }

            context("when there are no stored chapters") {
                beforeEach {
                    future = subject.book()
                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service for new data") {
                    expect(syncService.checkCalls).toEventually(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(subpage(named: "api/book.json")))
                    expect(call.etag).to(equal(""))
                }

                itBehavesLikeNewDataWasReturned {
                    it("doesn't remove any chapters") {

                    }
                }

                describe("if the sync service comes back with no new data") {
                    // Shouldn't happen!

                    beforeEach {
                        syncService.checkPromises.last?.resolve(.success(.noNewContent))
                    }

                    it("resolves the future with a cache error") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(beNil())
                        expect(future.value?.error).to(equal(ServiceError.cache))
                    }
                }

                describe("when the sync service comes back with an error") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.failure(.unknown))
                    }

                    it("forwards the error") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.unknown))
                    }
                }
            }

            context("when there are stored chapters") {
                beforeEach {
                    objectContext.performAndWait {
                        let book = NSEntityDescription.insertNewObject(forEntityName: "CoreDataBook", into: objectContext) as! CoreDataBook
                        book.etag = "my_etag"
                        book.url = bookURL
                        book.title = "existing title"

                        cdchapters = (1..<5).map { index in
                            return coreDataChapterFactory(
                                objectContext: objectContext,
                                book: book,
                                etag: nil,
                                contentURL: subpage(named: "\(index).html"),
                                content: nil,
                                title: "Chapter \(index)"
                            )
                        }

                        cdbook = book
                        try! objectContext.save()
                    }

                    future = subject.book()
                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service to update the chapter") {
                    expect(syncService.checkCalls).toEventually(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(subpage(named: "api/book.json")))
                    expect(call.etag).to(equal("my_etag"))
                }

                itBehavesLikeNewDataWasReturned {
                    it("informs the delegate that some chapters were removed") {
                        expect(delegate.didRemoveChapterCalls).toEventually(haveCount(4))

                        let expectedChapters: [Chapter] = (1..<5).map { index in
                            return Chapter(
                                title: "Chapter \(index)",
                                contentURL: subpage(named: "\(index).html"),
                                subchapters: []
                            )
                        }

                        expect(delegate.didRemoveChapterCalls).to(contain(expectedChapters))
                    }
                }

                describe("when the sync service comes back with no new data") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.success(.noNewContent))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal(Book(
                            title: "existing title",
                            chapters: [
                                Chapter(title: "Chapter 1", contentURL: subpage(named: "1.html"), subchapters: []),
                                Chapter(title: "Chapter 2", contentURL: subpage(named: "2.html"), subchapters: []),
                                Chapter(title: "Chapter 3", contentURL: subpage(named: "3.html"), subchapters: []),
                                Chapter(title: "Chapter 4", contentURL: subpage(named: "4.html"), subchapters: []),
                            ])))
                    }
                }

                describe("when the sync service comes back with an error") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.failure(.unknown))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal(Book(
                            title: "existing title",
                            chapters: [
                                Chapter(title: "Chapter 1", contentURL: subpage(named: "1.html"), subchapters: []),
                                Chapter(title: "Chapter 2", contentURL: subpage(named: "2.html"), subchapters: []),
                                Chapter(title: "Chapter 3", contentURL: subpage(named: "3.html"), subchapters: []),
                                Chapter(title: "Chapter 4", contentURL: subpage(named: "4.html"), subchapters: []),
                            ])))
                    }
                }
            }
        }

        describe("-content(of:)") {
            var future: Future<Result<String, ServiceError>>!

            var cdchapter: CoreDataChapter?

            let chapter = Chapter(title: "Whatever", contentURL: URL(string: "https://example.com/my_chapter")!, subchapters: [])

            beforeEach {
                objectContext.performAndWait {
                    let newChapter = NSEntityDescription.insertNewObject(forEntityName: "CoreDataChapter", into: objectContext) as! CoreDataChapter
                    newChapter.contentURL = chapter.contentURL
                    newChapter.title = "My title"
                    newChapter.etag = nil
                    newChapter.content = nil

                    cdchapter = newChapter
                    try! objectContext.save()
                }
            }

            func itBehavesLikeNewDataWasReturned() {
                describe("when the sync service comes back with new data") {
                    let content = """
<html><body><div id="page-wrapper" class="page-wrapper"><div class="page"><div id="content" class="content"><main>New Content, woo!</main></div></div></div></body></html>
"""
                    beforeEach {
                        guard let data = content.data(using: .utf8) else {
                            fail("Unable to serialize content")
                            return
                        }
                        syncService.checkPromises.last?.resolve(.success(.updateAvailable(content: data, etag: "new_content")))
                    }

                    it("resolves the future with the parsed chapter content") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal("New Content, woo!"))
                    }

                    it("updates the stored chapters") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        objectContext.performAndWait {
                            objectContext.refreshAllObjects()
                            let results = (try! objectContext.fetch(NSFetchRequest(entityName: "CoreDataChapter")))
                            expect(results).to(haveCount(1))
                            cdchapter = results.first as? CoreDataChapter
                        }

                        expect(cdchapter?.etag).to(equal("new_content"))
                        expect(cdchapter?.contentURL).to(equal(chapter.contentURL))

                        assertCoreDataChapter(chapter: cdchapter!, book: nil, url: chapter.contentURL, title: "My title",
                                              etag: "new_content", content: "New Content, woo!")

                        expect(cdchapter?.subchapters?.count).to(equal(0))
                    }
                }
            }

            context("and there is no content for the chapter") {
                beforeEach {
                    future = subject.content(of: chapter)

                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service for the chapter content") {
                    expect(syncService.checkCalls).to(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(chapter.contentURL))
                    expect(call.etag).to(equal(""))
                }

                itBehavesLikeNewDataWasReturned()

                describe("if the sync service comes back with no new data") {
                    // Shouldn't happen!

                    beforeEach {
                        syncService.checkPromises.last?.resolve(.success(.noNewContent))
                    }

                    it("resolves the future with a cache error") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(ServiceError.cache))
                    }
                }

                describe("when the sync service comes back with an error") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.failure(.unknown))
                    }

                    it("forwards the error") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.unknown))
                    }
                }
            }

            context("and there is content for the chapter") {
                beforeEach {
                    objectContext.performAndWait {
                        cdchapter!.etag = "an etag"
                        cdchapter!.content = "<html><body>Hello World</body></html>"

                        try! objectContext.save()
                    }

                    future = subject.content(of: chapter)

                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service to update the chapter") {
                    expect(syncService.checkCalls).to(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(chapter.contentURL))
                    expect(call.etag).to(equal("an etag"))
                }

                itBehavesLikeNewDataWasReturned()

                describe("when the sync service comes back with no new data") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.success(.noNewContent))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal("<html><body>Hello World</body></html>"))
                    }
                }

                describe("when the sync service comes back with an error") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.failure(.unknown))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal("<html><body>Hello World</body></html>"))
                    }
                }
            }
        }
    }
}

final class FakeBookServiceDelegate: BookServiceDelegate {
    private(set) var didRemoveChapterCalls: [Chapter] = []
    func didRemove(chapter: Chapter) {
        self.didRemoveChapterCalls.append(chapter)
    }
}
