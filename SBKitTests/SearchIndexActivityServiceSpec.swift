import Quick
import Nimble
import CoreSpotlight
import Foundation_PivotalSpecHelper

@testable import SBKit

final class SearchIndexActivityServiceSpec: QuickSpec {
    override func spec() {
        var subject: SearchActivityService!
        var searchIndex: FakeSearchIndex!
        var searchQueue: PSHKFakeOperationQueue!

        beforeEach {
            searchIndex = FakeSearchIndex()
            searchQueue = PSHKFakeOperationQueue()

            subject = SearchActivityService(searchIndex: searchIndex, searchQueue: searchQueue)
        }

        describe("Updating the SearchIndex") {
            describe("Adding things to the search index") {
                let chapter1 = Chapter(title: "Chapter 1", contentURL: URL(string: "https://example.com/1")!, subchapters: [])
                let chapter1Content = "some content"

                beforeEach {
                    subject.update(chapter: chapter1, content: chapter1Content)
                    searchQueue.runNextOperation()
                }

                it("does not index the item yet") {
                    expect(searchIndex.indexSearchableItemsCalls).to(beEmpty())
                }

                describe("deleting things") {
                    let chapterToRemove = Chapter(title: "Chapter 0", contentURL: URL(string: "https://example.com/0")!, subchapters: [])

                    beforeEach {
                        subject.didRemove(chapter: chapterToRemove)
                        searchQueue.runNextOperation()
                    }

                    it("does not update the index yet") {
                        expect(searchIndex.deleteSearchableItemsCalls).to(beEmpty())
                    }

                    describe("Ending the update") {
                        beforeEach {
                            subject.endRefresh()

                            searchQueue.runNextOperation()
                        }

                        it("updates the index with updated chapters") {
                            expect(searchIndex.indexSearchableItemsCalls).to(haveCount(1))
                            guard let call = searchIndex.indexSearchableItemsCalls.last else {
                                fail("no calls to add something to the search index")
                                return
                            }
                            expect(call.completionHandler).to(beNil())
                            expect(call.items).to(haveCount(1))
                            expect(call.items.first?.uniqueIdentifier).to(equal(chapter1.contentURL.absoluteString))
                            expect(call.items.first?.domainIdentifier).to(equal("com.rachelbrindle.second_brain.chapter"))
                        }

                        it("removes the removed chapters from the index") {
                            expect(searchIndex.deleteSearchableItemsCalls).to(haveCount(1))
                            guard let call = searchIndex.deleteSearchableItemsCalls.last else {
                                fail("no calls to remove thinsg from the search index")
                                return
                            }
                            expect(call.handler).to(beNil())
                            expect(call.identifier).to(equal([
                                chapterToRemove.contentURL.absoluteString
                                ]))
                        }

                        it("commits the update") {
                            expect(searchIndex.isUpdating).to(beFalsy())
                        }
                    }
                }
            }
        }
    }
}
