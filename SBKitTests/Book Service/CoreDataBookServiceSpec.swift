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

        let storeCoordinator = try! persistentStoreCoordinatorFactory()
        try! addInMemoryStorage(to: storeCoordinator)
        var objectContext: NSManagedObjectContext!
        var syncService: FakeSyncService!
        var queueJumper: OperationQueueJumper!

        let bookURL = URL(string: "https://example.com")!

        func subpage(named: String) -> URL {
            return bookURL.appendingPathComponent(named, isDirectory: false)
        }

        beforeEach {
            objectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            objectContext.persistentStoreCoordinator = storeCoordinator

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

            syncService = FakeSyncService()

            queueJumper = OperationQueueJumper(queue: .main)

            subject = CoreDataBookService(
                persistentStoreCoordinator: storeCoordinator,
                syncService: syncService,
                queueJumper: queueJumper,
                bookURL: bookURL
            )
        }

        describe("-chapters()") {
            var future: Future<Result<[Chapter], ServiceError>>!

            var cdbook: CoreDataBook?
            var cdchapters: [CoreDataChapter] = []

            func itBehavesLikeNewDataWasReturned() {
                describe("when the sync service comes back with new data") {
                    let chapters: [[String: Any]] = [
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
                    ]
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
                        expect(future.value?.value).to(equal([
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
                            ]))
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
                }
            }

            context("when there are no stored chapters") {
                beforeEach {
                    future = subject.chapters()
                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service for new data") {
                    expect(syncService.checkCalls).toEventually(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(subpage(named: "api/chapters.json")))
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

            fcontext("when there are stored chapters") {
                beforeEach {
                    objectContext.performAndWait {
                        let book = NSEntityDescription.insertNewObject(forEntityName: "CoreDataBook", into: objectContext) as! CoreDataBook
                        book.etag = "my_etag"
                        book.url = bookURL

                        cdchapters = (1..<5).map { index in
                            return cdChapterFactory(
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

                    future = subject.chapters()
                    expect(syncService.checkPromises).toEventuallyNot(beEmpty())
                }

                it("asks the sync service to update the chapter") {
                    expect(syncService.checkCalls).toEventually(haveCount(1))

                    guard let call = syncService.checkCalls.last else { return }

                    expect(call.url).to(equal(subpage(named: "api/chapters.json")))
                    expect(call.etag).to(equal("my_etag"))
                }

                itBehavesLikeNewDataWasReturned()

                describe("when the sync service comes back with no new data") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.success(.noNewContent))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal([
                            Chapter(title: "Chapter 1", contentURL: subpage(named: "1.html"), subchapters: []),
                            Chapter(title: "Chapter 2", contentURL: subpage(named: "2.html"), subchapters: []),
                            Chapter(title: "Chapter 3", contentURL: subpage(named: "3.html"), subchapters: []),
                            Chapter(title: "Chapter 4", contentURL: subpage(named: "4.html"), subchapters: []),
                        ]))
                    }
                }

                describe("when the sync service comes back with an error") {
                    beforeEach {
                        syncService.checkPromises.last?.resolve(.failure(.unknown))
                    }

                    it("returns the chapter content as stored in core data") {
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal([
                            Chapter(title: "Chapter 1", contentURL: subpage(named: "1.html"), subchapters: []),
                            Chapter(title: "Chapter 2", contentURL: subpage(named: "2.html"), subchapters: []),
                            Chapter(title: "Chapter 3", contentURL: subpage(named: "3.html"), subchapters: []),
                            Chapter(title: "Chapter 4", contentURL: subpage(named: "4.html"), subchapters: []),
                        ]))
                    }
                }
            }
        }
    }
}

private func cdChapterFactory(objectContext: NSManagedObjectContext, book: CoreDataBook, etag: String?, contentURL: URL, content: String?, title: String) -> CoreDataChapter {
    let chapter = NSEntityDescription.insertNewObject(forEntityName: "CoreDataChapter", into: objectContext) as! CoreDataChapter
    chapter.etag = etag
    chapter.contentURL = contentURL
    chapter.content = content
    chapter.title = title
    chapter.book = book
    return chapter
}

private func assertCoreDataChapter(chapter: CoreDataChapter, book: CoreDataBook?, url: URL, title: String, etag: String?, content: String?, file: FileString = #file, line: UInt = #line) {
    if let cdbook = book {
        expect(chapter.book, file: file, line: line).to(equal(cdbook))
    } else {
        expect(chapter.book, file: file, line: line).to(beNil())
    }
    expect(chapter.contentURL, file: file, line: line).to(equal(url))
    expect(chapter.title, file: file, line: line).to(equal(title))
    if content == nil {
        expect(chapter.content, file: file, line: line).to(beNil())
    } else {
        expect(chapter.content, file: file, line: line).to(equal(content))
    }
    if etag == nil {
        expect(chapter.etag, file: file, line: line).to(beNil())
    } else {
        expect(chapter.etag, file: file, line: line).to(equal(etag))
    }
}
