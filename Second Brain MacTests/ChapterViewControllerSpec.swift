import Cocoa
import Quick
import Nimble
import Result
import WebKit
import CBGPromise

@testable import SBKit
@testable import Second_Brain

final class ChapterViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterViewController!

        var bookService: FakeBookService!
        var htmlWrapper: SimpleHTMLWrapper!
        var activityService: ActivityService!
        var urlOpener: FakeURLOpener!

        var selectionPublisher: ChapterSelectorPubSub!

        let chapter = Chapter(title: "My Title", contentURL: URL(string: "https://example.com/chapter.html")!, subchapters: [])

        beforeEach {
            bookService = FakeBookService()
            htmlWrapper = SimpleHTMLWrapper()
            activityService = SearchActivityService(searchIndex: FakeSearchIndex(), searchQueue: OperationQueue())
            urlOpener = FakeURLOpener()

            selectionPublisher = ChapterSelectorPubSub()

            let storyboard = NSStoryboard(name: "UI", bundle: Bundle(for: ChapterViewController.self))

            subject = storyboard.instantiateController(withIdentifier: "ChapterViewController") as? ChapterViewController
            expect(subject).toNot(beNil())
            subject.bookService = bookService
            subject.htmlWrapper = htmlWrapper
            subject.activityService = activityService
            subject.chapterSelectionPublisher = selectionPublisher
            subject.urlOpener = urlOpener
            subject.view.layout()
        }

        describe("loading chapter content") {
            beforeEach {
                selectionPublisher.select(chapter: chapter)
            }

            it("sets the userActivity to an activity describing the chapter") {
                expect(subject.userActivity).toNot(beNil())

                guard let activity = subject.userActivity else { return }

                expect(activity.webpageURL).to(equal(chapter.contentURL))
                expect(activity.keywords).to(equal([chapter.title]))
                expect(activity.activityType).to(equal(ChapterActivityType))
                expect(activity.userInfo as? [String: String]).to(equal(["urlString": chapter.contentURL.absoluteString]))
                expect(activity.isEligibleForSearch).to(beTruthy())
                expect(activity.isEligibleForHandoff).to(beTruthy())
                expect(activity.isEligibleForPublicIndexing).to(beFalsy()) // Doesn't make sense for this app.
            }

            it("asks for the chapter's content") {
                expect(bookService.contentsCalls).to(equal([chapter]))
            }

            describe("when the content request succeeds") {
                guard let url = Bundle(for: self.classForCoder).url(forResource: "content", withExtension: "html") else {
                    it("could not find the content") {
                        fail("Unable to get url for content.html")
                    }
                    return
                }
                guard let htmlString = try? String(contentsOf: url, encoding: .utf8) else {
                    it("could not read the content") {
                        fail("Unable to read contents of content.html")
                    }
                    return
                }

                beforeEach {
                    bookService.contentsPromises.last?.resolve(.success(htmlString))
                }

                it("loads the html content") {
                    let expectedString = "<html><body>\(htmlString)</body></html>"

                    expect(subject.webView.lastHTMLStringLoaded).to(equal(expectedString))
                    expect(htmlWrapper.wrapCalls).to(equal([htmlString]))
                }
            }

            describe("when the content request fails due to a server error") {
                beforeEach {
                    bookService.contentsPromises.last?.resolve(.failure(.network(.http(nil))))
                }

                xit("displays an alert") {
                    fail("Add infrastructure to display the alert")
                }
            }

            describe("the webview's ui delegate") {
                describe("when the user clicks a link") {
                    var decisions: [WKNavigationActionPolicy] = []

                    beforeEach {
                        decisions = []
                    }

                    context("to an external site") {
                        let request = URLRequest(url: URL(string: "https://example.com/my_url")!)
                        let action = FakeNavigationAction(navigationType: .linkActivated, request: request)

                        beforeEach {
                            subject.webView.navigationDelegate?.webView?(
                                subject.webView,
                                decidePolicyFor: action
                            ) { policy in
                                decisions.append(policy)
                            }
                        }

                        it("asks if the url is to an external site or another chapter") {
                            fail("Create a service to do this")
                        }

                        it("denies the navigation") {
                            expect(decisions).to(equal([.cancel]))
                        }

                        it("opens the url in the user's browser") {
                            expect(urlOpener.openedURLs).to(equal([request.url!]))
                        }
                    }

                    context("to a different chapter") {
                        let request = URLRequest(url: URL(string: "https://example.com/other_chapter")!)
                        let action = FakeNavigationAction(navigationType: .linkActivated, request: request)

                        beforeEach {
                            subject.webView.navigationDelegate?.webView?(
                                subject.webView,
                                decidePolicyFor: action
                            ) { policy in
                                decisions.append(policy)
                            }
                        }

                        it("asks if the url is to an external site or another chapter") {
                            fail("Create a service to do this")
                        }

                        it("allows the navigation") {
                            expect(decisions).to(equal([.allow]))
                        }

                        it("sends a select chapter notification") {
                            fail("send a select chapter notification")
                        }

                        it("doesn't open the url in the user's browser") {
                            expect(urlOpener.openedURLs).to(beEmpty())
                        }
                    }

                    context("within the same chapter") { // like an anchor link.
                        var urlComponents = URLComponents(url: chapter.contentURL, resolvingAgainstBaseURL: true)!
                        urlComponents.fragment = "some_point"
                        let request = URLRequest(url: urlComponents.url!)
                        let action = FakeNavigationAction(navigationType: .linkActivated, request: request)

                        beforeEach {
                            subject.webView.navigationDelegate?.webView?(
                                subject.webView,
                                decidePolicyFor: action
                            ) { policy in
                                decisions.append(policy)
                            }
                        }

                        it("allows the navigation") {
                            expect(decisions).to(equal([.allow]))
                        }

                        it("does not send a select chapter notification") {
                            fail("don't send a select chapter notification")
                        }

                        it("doesn't open the url in the user's browser") {
                            expect(urlOpener.openedURLs).to(beEmpty())
                        }
                    }
                }
            }
        }
    }
}
