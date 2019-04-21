import Cocoa
import Quick
import Nimble
import Result
import Swinject
import CBGPromise
import SwinjectStoryboard

@testable import SBKit
@testable import Second_Brain

final class ChapterTreeViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterTreeViewController!

        var bookService: FakeBookService!

        beforeEach {
            bookService = FakeBookService()

            let storyboard = NSStoryboard(name: "Main", bundle: Bundle(for: ChapterTreeViewController.self))

            subject = storyboard.instantiateController(withIdentifier: "ChapterTreeController") as? ChapterTreeViewController
            expect(subject).toNot(beNil())
            subject.bookService = bookService
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layout()
            }

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
                    chapterFactory(title: "Title 3"),
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
    }
}
