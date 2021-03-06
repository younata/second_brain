import Quick
import UIKit
import Nimble

@testable import Second_Brain
@testable import SBKit

final class ChapterViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterViewController!

        var bookService: FakeBookService!
        var htmlWrapper: SimpleHTMLWrapper!
        var activityService: ActivityService!

        let chapter = Chapter(title: "My Title", contentURL: URL(string: "https://example.com/chapter.html")!, subchapters: [])

        beforeEach {
            bookService = FakeBookService()
            htmlWrapper = SimpleHTMLWrapper()
            activityService = SearchActivityService(searchIndex: FakeSearchIndex(), searchQueue: OperationQueue())

            subject = ChapterViewController(bookService: bookService, htmlWrapper: htmlWrapper, activityService: activityService, chapter: chapter)
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
            expect(activity.isEligibleForPrediction).to(beFalsy())
            expect(activity.isEligibleForPublicIndexing).to(beFalsy()) // Doesn't make sense for this app.
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layoutIfNeeded()
            }

            it("asks for the chapter's content") {
                expect(bookService.contentsCalls).to(equal([chapter]))
            }

            it("sets the view controller's title") {
                expect(subject.title).to(equal("My Title"))
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

                it("shows the progress bar") {
                    expect(subject.progressBar.isHidden).to(beFalsy())
                }

                it("loads the html content") {
                    let expectedString = "<html><body>\(htmlString)</body></html>"

                    expect(subject.webView.lastHTMLStringLoaded).to(equal(expectedString))
                    expect(htmlWrapper.wrapCalls).to(equal([htmlString]))
                }

                describe("when the content loads") {
                    beforeEach {
                        subject.webView.navigationDelegate?.webView?(subject.webView, didFinish: nil)
                    }

                    it("hides the progressIndicator") {
                        expect(subject.progressBar.isHidden) == true
                    }
                }
            }

            describe("when the content request fails due to a server error") {
                beforeEach {
                    bookService.contentsPromises.last?.resolve(.failure(.network(.http(nil))))
                }

                it("alerts the user without showing an alert") {
                    expect(subject.warningView?.label.text).to(equal("Unable to get chapter content, check the server"))
                }
            }

            describe("when the content request fails otherwise") {
                beforeEach {
                    bookService.contentsPromises.last?.resolve(.failure(.unknown))
                }

                it("alerts the user without showing an alert") {
                    expect(subject.warningView?.label.text).to(equal("Error fetching chapter: Try again later"))
                }
            }
        }
    }
}

