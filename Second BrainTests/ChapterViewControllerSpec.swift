import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import Second_Brain
@testable import SBKit

final class ChapterViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterViewController!

        var bookService: FakeBookService!

        beforeEach {
            bookService = FakeBookService()
            subject = ChapterViewController(bookService: bookService)
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layoutIfNeeded()
            }

            it("shows a spinner") {
                expect(subject.tableViewController.refreshControl?.isRefreshing).to(beTruthy())
            }

            it("asks for the book's chapters") {
                expect(bookService.chaptersPromises).to(haveCount(1))
            }

            it("gives the tableView an empty view so that it doesn't have the many lines") {
                expect(subject.tableView.tableFooterView).toNot(beNil())
            }

            it("sets up the tableDeleSource as the tableview's delegate and datasource") {
                expect(subject.tableView.delegate).to(beIdenticalTo(subject.tableDelesource))
                expect(subject.tableView.dataSource).to(beIdenticalTo(subject.tableDelesource))
            }

            func itRefreshesTheChapters(refreshCount: Int) {
                it("asks for the book's chapters") {
                    expect(bookService.chaptersPromises).to(haveCount(refreshCount))
                }

                describe("when the chapters come back") {
                    let chapters = [
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
                        ]
                    beforeEach {
                        guard bookService.chaptersPromises.count == refreshCount else {
                            return
                        }
                        bookService.chaptersPromises.last?.resolve(.success(chapters))
                    }

                    it("displays the chapters") {
                        expect(subject.tableDelesource.items).to(equal(chapters))
                    }

                    it("hides the spinner") {
                        expect(subject.tableViewController.refreshControl?.isRefreshing).to(beFalsy())
                    }
                }

                describe("when the chapters fail due to a server error") {
                    beforeEach {
                        guard bookService.chaptersPromises.count == refreshCount else {
                            return
                        }
                        bookService.chaptersPromises.last?.resolve(.failure(.network(.http(nil))))
                    }

                    it("alerts the user without showing an alert") {
                        expect(subject.warningView?.label.text).to(equal("Unable to get chapters, check the server"))
                    }
                }

                describe("when the chapters fail") {
                    beforeEach {
                        guard bookService.chaptersPromises.count == refreshCount else {
                            return
                        }
                        bookService.chaptersPromises.last?.resolve(.failure(.unknown))
                    }

                    it("alerts the user without showing an alert") {
                        expect(subject.warningView?.label.text).to(equal("Error getting chapters: Try again later"))
                    }
                }
            }

            itRefreshesTheChapters(refreshCount: 1)

            describe("pulling on the refresh control") {
                beforeEach {
                    // resolve the in-progress chapters promise here, rather than do it in response to the function.
                    bookService.chaptersPromises.last?.resolve(.success([]))

                    subject.tableViewController.refreshControl?.sendActions(for: .valueChanged)
                }

                itRefreshesTheChapters(refreshCount: 2)
            }
        }
    }
}
