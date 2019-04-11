import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import Second_Brain
@testable import SBKit

final class ChapterListViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterListViewController!

        var bookService: FakeBookService!
        var presentedChapters: [Chapter] = []

        beforeEach {
            bookService = FakeBookService()
            presentedChapters = []
            subject = ChapterListViewController(bookService: bookService, chapterViewControllerFactory: { chapter in
                presentedChapters.append(chapter)
                return ChapterViewController(bookService: bookService, htmlWrapper: SimpleHTMLWrapper(), activityService: SearchActivityService(), chapter: chapter)
            })
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layoutIfNeeded()
            }

            it("shows a spinner") {
                expect(subject.tableViewController.refreshControl?.isRefreshing).to(beTruthy())
            }

            it("asks for the book's contents") {
                expect(bookService.bookPromises).to(haveCount(1))
            }

            it("gives the tableView an empty view so that it doesn't have the many lines") {
                expect(subject.tableView.tableFooterView).toNot(beNil())
            }

            it("sets up the tableDeleSource as the tableview's delegate and datasource") {
                expect(subject.tableView.delegate).to(beIdenticalTo(subject.tableDelesource))
                expect(subject.tableView.dataSource).to(beIdenticalTo(subject.tableDelesource))
            }

            func itRefreshesTheBook(refreshCount: Int) {
                it("asks for the book's contents") {
                    expect(bookService.bookPromises).to(haveCount(refreshCount))
                }

                describe("when the book come back") {
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
                        guard bookService.bookPromises.count == refreshCount else {
                            return
                        }
                        bookService.bookPromises.last?.resolve(.success(book))
                    }

                    it("updates the title") {
                        expect(subject.title).to(equal("Book Title"))
                    }

                    it("displays the chapters") {
                        expect(subject.tableDelesource.items).to(equal(book.chapters))
                    }

                    it("hides the spinner") {
                        expect(subject.tableViewController.refreshControl?.isRefreshing).to(beFalsy())
                    }

                    describe("selecting a chapter") {
                        beforeEach {
                            subject.tableDelesource.onSelect?(book.chapters[2])
                        }

                        it("shows a chapter view controller inside of a UINavigationController") {
                            expect(subject.detail).to(beAKindOf(UINavigationController.self))

                            guard let navController = subject.detail as? UINavigationController else { return }
                            expect(navController.visibleViewController).to(beAKindOf(ChapterViewController.self))
                            expect(navController.hidesBarsOnSwipe).to(beTruthy())
                            expect(navController.hidesBarsOnTap).to(beTruthy())
                            expect(presentedChapters).to(equal([book.chapters[2]]))
                        }
                    }
                }

                describe("when the chapters fail due to a server error") {
                    beforeEach {
                        guard bookService.bookPromises.count == refreshCount else {
                            return
                        }
                        bookService.bookPromises.last?.resolve(.failure(.network(.http(nil))))
                    }

                    it("alerts the user without showing an alert") {
                        expect(subject.warningView?.label.text).to(equal("Unable to get chapters, check the server"))
                    }
                }

                describe("when the chapters fail") {
                    beforeEach {
                        guard bookService.bookPromises.count == refreshCount else {
                            return
                        }
                        bookService.bookPromises.last?.resolve(.failure(.unknown))
                    }

                    it("alerts the user without showing an alert") {
                        expect(subject.warningView?.label.text).to(equal("Error getting chapters: Try again later"))
                    }
                }
            }

            itRefreshesTheBook(refreshCount: 1)

            describe("pulling on the refresh control") {
                beforeEach {
                    // resolve the in-progress chapters promise here, rather than do it in response to the function.
                    bookService.bookPromises.last?.resolve(.success(Book(title: "", chapters: [])))

                    subject.tableViewController.refreshControl?.sendActions(for: .valueChanged)
                }

                itRefreshesTheBook(refreshCount: 2)
            }
        }
    }
}
