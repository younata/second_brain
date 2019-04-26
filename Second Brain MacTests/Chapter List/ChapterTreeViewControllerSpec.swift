import Cocoa
import Quick
import Nimble
import Result
import CBGPromise

@testable import SBKit
@testable import Second_Brain

final class ChapterTreeViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterTreeViewController!

        var bookService: FakeBookService!
        var publisher: ChapterSelectorPubSub!

        var chapterSubscriber: FakeChapterSubscriber!

        beforeEach {
            bookService = FakeBookService()
            publisher = ChapterSelectorPubSub()
            chapterSubscriber = FakeChapterSubscriber()
            publisher.add(subscriber: chapterSubscriber)

            let storyboard = NSStoryboard(name: "UI", bundle: Bundle(for: ChapterTreeViewController.self))

            subject = storyboard.instantiateController(withIdentifier: "ChapterTreeController") as? ChapterTreeViewController
            expect(subject).toNot(beNil())
            subject.bookService = bookService
            subject.selectionPublisher = publisher
            subject.view.layout()
        }

        describe("when the view loads") {
            it("makes a request to the book service") {
                expect(bookService.bookPromises).to(haveCount(1))
            }

            describe("when the book promise succeeds") {
                let book = Book(title: "Book Title", chapters: [
                    chapterFactory(title: "Title 1"),
                    chapterFactory(title: "Title 2", subchapters: [
                        chapterFactory(title: "Title 2.1"),
                        chapterFactory(title: "Title 2.2", subchapters: [
                            chapterFactory(title: "Title 2.2.1"),
                            chapterFactory(title: "Title 2.2.2"),
                            ]),
                        chapterFactory(title: "Title 2.3")
                        ]),
                    chapterFactory(title: "Title 3", contentURL: URL(string: "https://example.com/3/")!),
                    chapterFactory(title: "Title 4", subchapters: [
                        chapterFactory(title: "Title 4.1")
                        ]),
                    ])

                beforeEach {
                    guard bookService.bookPromises.count == 1 else { return }
                    bookService.bookPromises.last?.resolve(.success(book))
                }

                it("updates the title") {
                    expect(subject.title).to(equal("Book Title"))
                }

                it("displays the chapters using the tree controller") {
                    expect(subject.treeController.content).to(beAKindOf([CocoaChapter].self))
                    guard let receivedChapters = subject.treeController.content as? [CocoaChapter] else { return }

                    let expectedChapters = book.chapters.map(CocoaChapter.init)
                    expect(receivedChapters).to(equal(expectedChapters))
                }

                describe("when the user selects a cell") {
                    beforeEach {
                        guard let node = subject.treeController.arrangedObjects.children?.first else { return }
                        subject.treeController.addSelectionIndexPaths([node.indexPath])
                    }

                    it("sends a selectedChapter notification") {
                        expect(chapterSubscriber.selectedChapters.last).to(equal(book.chapters.first!))
                    }
                }

                describe("the outline view's delegate") {
                    it("exists") {
                        expect(subject.outlineView.delegate).toNot(beNil())
                    }

                    describe("tooltip") {
                        it("shows the url for the chapter") {
                            var rect = NSRect(x: 0, y: 0, width: 0, height: 0)
                            let tooltip = subject.outlineView.delegate?.outlineView?(
                                subject.outlineView,
                                toolTipFor: NSCell(imageCell: nil), // doesn't matter
                                rect: &rect,
                                tableColumn: nil,
                                item: CocoaChapter(chapter: book.chapters[2]),
                                mouseLocation: NSPoint(x: 0, y: 0)
                            )
                            expect(tooltip).to(equal("https://example.com/3/"))
                        }
                    }
                }
            }

            describe("when the book promise fails") {
                beforeEach {
                    guard bookService.bookPromises.count == 1 else { return }
                    bookService.bookPromises.last?.resolve(.failure(.unknown))
                }

                xit("displays an alert") {
                    fail("display an alert")
                }
            }
        }

        describe("resuming from an activity") {
            let handedOffChapter = chapterFactory(title: "Title 2.3", contentURL: URL(string: "https://example.com/2/3")!)
            var didHandoff: Bool? = nil

            beforeEach {
                didHandoff = nil
            }

            context("before the book's contents are available") {
                beforeEach {
                    didHandoff = subject.resumeFromActivity(url: handedOffChapter.contentURL)
                }

                it("returns true preemptively") {
                    expect(didHandoff).to(beTrue())
                }

                it("does not refetch the book") {
                    expect(bookService.bookPromises).to(haveCount(1))
                }

                describe("when the book request succeeds") {
                    context("and the chapter is in the book") {
                        let book = Book(title: "Book Title", chapters: [
                            chapterFactory(title: "Title 1"),
                            chapterFactory(title: "Title 2", subchapters: [
                                chapterFactory(title: "Title 2.1"),
                                chapterFactory(title: "Title 2.2", subchapters: [
                                    chapterFactory(title: "Title 2.2.1"),
                                    chapterFactory(title: "Title 2.2.2"),
                                    ]),
                                handedOffChapter
                                ]),
                            chapterFactory(title: "Title 3"),
                            chapterFactory(title: "Title 4", subchapters: [
                                chapterFactory(title: "Title 4.1")
                                ]),
                            ])

                        beforeEach {
                            guard bookService.bookPromises.count == 1 else { return }
                            bookService.bookPromises.last?.resolve(.success(book))
                        }

                        it("does not refetch the book") {
                            expect(bookService.bookPromises).to(haveCount(1))
                        }

                        it("finds the chapter and sends a selectedChapter notification") {
                            expect(chapterSubscriber.selectedChapters.last).to(equal(handedOffChapter))
                        }
                    }
                }
            }

            context("after the book's contents are available") {
                context("and the chapter is in the book") {
                    let book = Book(title: "Book Title", chapters: [
                        chapterFactory(title: "Title 1"),
                        chapterFactory(title: "Title 2", subchapters: [
                            chapterFactory(title: "Title 2.1"),
                            chapterFactory(title: "Title 2.2", subchapters: [
                                chapterFactory(title: "Title 2.2.1"),
                                chapterFactory(title: "Title 2.2.2"),
                                ]),
                            handedOffChapter
                            ]),
                        chapterFactory(title: "Title 3"),
                        chapterFactory(title: "Title 4", subchapters: [
                            chapterFactory(title: "Title 4.1")
                            ]),
                        ])

                    beforeEach {
                        guard bookService.bookPromises.count == 1 else { return }
                        bookService.bookPromises.last?.resolve(.success(book))

                        didHandoff = subject.resumeFromActivity(url: handedOffChapter.contentURL)
                    }

                    it("does not refetch the book") {
                        expect(bookService.bookPromises).to(haveCount(1))
                    }

                    it("finds the chapter and sends a selectedChapter notification") {
                        expect(chapterSubscriber.selectedChapters.last).to(equal(handedOffChapter))
                    }

                    it("returns true") {
                        expect(didHandoff).to(beTrue())
                    }
                }

                context("and the chapter is not in the book") {
                    let book = Book(title: "Book Title", chapters: [
                        chapterFactory(title: "Title 1"),
                        chapterFactory(title: "Title 2", subchapters: [
                            chapterFactory(title: "Title 2.1"),
                            chapterFactory(title: "Title 2.2", subchapters: [
                                chapterFactory(title: "Title 2.2.1"),
                                chapterFactory(title: "Title 2.2.2"),
                                ]),
                            ]),
                        chapterFactory(title: "Title 3"),
                        chapterFactory(title: "Title 4", subchapters: [
                            chapterFactory(title: "Title 4.1")
                            ]),
                        ])

                    beforeEach {
                        guard bookService.bookPromises.count == 1 else { return }
                        bookService.bookPromises.last?.resolve(.success(book))

                        didHandoff = subject.resumeFromActivity(url: handedOffChapter.contentURL)
                    }

                    it("returns false") {
                        expect(didHandoff).to(beFalse())
                    }
                }
            }
        }
    }
}

private final class FakeChapterSubscriber: ChapterSelectionSubscriber {
    fileprivate private(set) var selectedChapters: [Chapter] = []

    func didSelect(chapter: Chapter) {
        self.selectedChapters.append(chapter)
    }
}
