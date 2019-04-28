import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import CoreSpotlight
import UIKit_PivotalSpecHelperStubs

@testable import Second_Brain
@testable import SBKit

final class ChapterListViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterListViewController!

        var bookService: FakeBookService!
        var notificationCenter: NotificationCenter!
        var presentedChapters: [Chapter] = []

        beforeEach {
            bookService = FakeBookService()
            notificationCenter = NotificationCenter()
            presentedChapters = []

            let activityService = SearchActivityService(searchIndex: FakeSearchIndex(), searchQueue: OperationQueue())

            subject = ChapterListViewController(bookService: bookService, notificationCenter: notificationCenter, chapterViewControllerFactory: { chapter in
                presentedChapters.append(chapter)
                return ChapterViewController(bookService: bookService, htmlWrapper: SimpleHTMLWrapper(), activityService: activityService, chapter: chapter)
            })
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layoutIfNeeded()
            }

            it("shows a spinner") {
                expect(subject.tableView.refreshControl?.isRefreshing).to(beTruthy())
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
                        expect(subject.tableView.refreshControl?.isRefreshing).to(beFalsy())
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

                    subject.tableView.refreshControl?.sendActions(for: .valueChanged)
                }

                itRefreshesTheBook(refreshCount: 2)
            }

            describe("when book service notifications are posted") {
                beforeEach {
                    notificationCenter.post(BookServiceNotification(total: 4, completed: 1, errorMessage: nil).bookNotification())
                }

                it("unhides the progress view") {
                    expect(subject.bookLoadProgress.isHidden).to(beFalsy())
                }

                describe("if they arrive out of order") {
                    beforeEach {
                        let firstNotification = BookServiceNotification(
                            total: 4,
                            completed: 2,
                            errorMessage: nil
                        )

                        let secondNotification = BookServiceNotification(
                            total: 4,
                            completed: 3,
                            errorMessage: nil
                        )

                        notificationCenter.post(secondNotification.chapterNotification())
                        notificationCenter.post(firstNotification.chapterNotification())
                    }

                    it("has the progress bar show the information for the more complete notification") {
                        expect(subject.bookLoadProgress.progress).to(beCloseTo(0.75))
                    }
                }

                describe("if the last notification arrives before the a previous notification") {
                    beforeEach {
                        let lastNotification = BookServiceNotification(
                            total: 4,
                            completed: 4,
                            errorMessage: nil
                        )

                        let thirdNotification = BookServiceNotification(
                            total: 4,
                            completed: 3,
                            errorMessage: nil
                        )

                        notificationCenter.post(lastNotification.chapterNotification())
                        notificationCenter.post(thirdNotification.chapterNotification())
                    }

                    it("has the progress bar show the information for the more complete notification") {
                        expect(subject.bookLoadProgress.progress).to(beCloseTo(1.0))
                    }

                    it("hides the progress bar, still") {
                        expect(subject.bookLoadProgress.isHidden).to(beTruthy())
                    }
                }

                describe("once the progress completes") {
                    beforeEach {
                        notificationCenter.post(BookServiceNotification(total: 4, completed: 4, errorMessage: nil).chapterNotification())
                    }

                    it("fills up the progress bar") {
                        expect(subject.bookLoadProgress.progress).to(beCloseTo(1.0))
                    }

                    it("hides the progress bar") {
                        expect(subject.bookLoadProgress.isHidden).to(beTruthy())
                    }
                }
            }
        }

        func itBehavesLikeResumingFromAnActivityDescribingAChapter(_ resume: @escaping () -> Bool) {
            describe("it behaves like resuming from an activity describing a chapter") {
                let activity = NSUserActivity(activityType: ChapterActivityType)
                activity.userInfo = ["urlString": "https://example.com/chapter/1.html"]

                var resumeResult: Bool!

                func itBehavesLikeFetchingABook() {
                    describe("if the book fetch is successful") {
                        context("and the chapter is among the book's chapters") {
                            let theChapter = Chapter(title: "Yep", contentURL: URL(string: "https://example.com/chapter/1.html")!, subchapters: [])
                            let book = Book(title: "", chapters: [
                                Chapter(title: "nope", contentURL: URL(string: "https://example.com/nope.html")!, subchapters: [
                                    theChapter
                                    ])
                                ])

                            beforeEach {
                                bookService.bookPromises.last?.resolve(.success(book))
                            }

                            it("shows a chapter view controller inside of a UINavigationController") {
                                expect(subject.detail).to(beAKindOf(UINavigationController.self))

                                guard let navController = subject.detail as? UINavigationController else { return }
                                expect(navController.visibleViewController).to(beAKindOf(ChapterViewController.self))
                                expect(navController.hidesBarsOnSwipe).to(beTruthy())
                                expect(navController.hidesBarsOnTap).to(beTruthy())
                                expect(presentedChapters).to(equal([theChapter]))
                            }
                        }

                        context("but the chapter is not among the book's chapters") {
                            let book = Book(title: "", chapters: [
                                Chapter(title: "", contentURL: URL(string: "https://example.com/nope.html")!, subchapters: [])
                                ])

                            beforeEach {
                                bookService.bookPromises.last?.resolve(.success(book))
                            }

                            it("alerts the user that the chapter was not found") {
                                expect(subject.warningView?.label.text).to(equal("Unable to open chapter: Not found"))
                            }
                        }
                    }

                    describe("If the book fetch fails") {
                        beforeEach {
                            bookService.bookPromises.last?.resolve(.failure(.unknown))
                        }

                        it("alerts the user that the chapter was not found") {
                            expect(subject.warningView?.label.text).to(equal("Unable to open chapter: Unable to get chapters"))
                        }
                    }
                }

                context("before the view even loads") {
                    beforeEach {
                        resumeResult = resume()
                    }

                    it("it returns true preemptively") {
                        expect(resumeResult).to(beTruthy())
                    }

                    it("fetches the books") {
                        expect(bookService.bookPromises).to(haveCount(1))
                    }

                    it("does not refetch the books after the view loads") {
                        subject.view.layoutIfNeeded()
                        expect(bookService.bookPromises).to(haveCount(1))
                    }

                    itBehavesLikeFetchingABook()
                }

                context("after the view loads") {
                    beforeEach {
                        subject.view.layoutIfNeeded()
                    }

                    context("before the book's contents are available") {
                        beforeEach {
                            expect(bookService.bookPromises).to(haveCount(1))
                            resumeResult = resume()
                        }

                        it("returns true preemptively") {
                            expect(resumeResult).to(beTruthy())
                        }

                        it("does not refetch the book") {
                            expect(bookService.bookPromises).to(haveCount(1))
                        }
                    }

                    context("after the book's contents have been retrieved") {
                        context("and the chapter is amongst the book's chapters") {
                            let theChapter = Chapter(title: "Yep", contentURL: URL(string: "https://example.com/chapter/1.html")!, subchapters: [])
                            let book = Book(title: "", chapters: [
                                Chapter(title: "nope", contentURL: URL(string: "https://example.com/nope.html")!, subchapters: [
                                    theChapter
                                    ])
                                ])

                            beforeEach {
                                bookService.bookPromises.last?.resolve(.success(book))

                                resumeResult = resume()
                            }

                            it("returns true") {
                                expect(resumeResult).to(beTruthy())
                            }

                            it("shows a chapter view controller inside of a UINavigationController") {
                                expect(subject.detail).to(beAKindOf(UINavigationController.self))

                                guard let navController = subject.detail as? UINavigationController else { return }
                                expect(navController.visibleViewController).to(beAKindOf(ChapterViewController.self))
                                expect(navController.hidesBarsOnSwipe).to(beTruthy())
                                expect(navController.hidesBarsOnTap).to(beTruthy())
                                expect(presentedChapters).to(equal([theChapter]))
                            }
                        }

                        context("and the chapter is not amongst the book's chapters") {
                            let book = Book(title: "", chapters: [
                                Chapter(title: "", contentURL: URL(string: "https://example.com/nope.html")!, subchapters: [])
                                ])

                            beforeEach {
                                bookService.bookPromises.last?.resolve(.success(book))

                                subject.warningView?.label.text = ""

                                resumeResult = resume()
                            }

                            it("returns false") {
                                expect(resumeResult).to(beFalsy())
                            }

                            it("does not alert the user") {
                                expect(subject.warningView?.label.text).to(equal(""))
                            }
                        }

                        context("and there was an error fetching the book") {
                            beforeEach {
                                bookService.bookPromises.last?.resolve(.failure(.unknown))

                                subject.warningView?.label.text = ""

                                resumeResult = resume()
                            }

                            it("returns false") {
                                expect(resumeResult).to(beFalsy())
                            }

                            it("does not alert the user") {
                                expect(subject.warningView?.label.text).to(equal(""))
                            }
                        }
                    }
                }
            }
        }

        describe("-resume(chapterActivity:)") {
            itBehavesLikeResumingFromAnActivityDescribingAChapter {
                let activity = NSUserActivity(activityType: ChapterActivityType)
                activity.userInfo = ["urlString": "https://example.com/chapter/1.html"]

                return subject.resume(chapterActivity: activity)
            }
        }

        describe("-resume(searchActivity:)") {
            itBehavesLikeResumingFromAnActivityDescribingAChapter {
                let activity = NSUserActivity(activityType: CSSearchableItemActionType)
                activity.userInfo = [CSSearchableItemActivityIdentifier: "https://example.com/chapter/1.html"]

                return subject.resume(searchActivity: activity)
            }
        }
    }
}
