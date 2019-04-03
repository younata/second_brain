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

        let chapter = Chapter(title: "My Title", contentURL: URL(string: "https://example.com/chapter.html")!, subchapters: [])

        beforeEach {
            bookService = FakeBookService()
            htmlWrapper = SimpleHTMLWrapper()

            subject = ChapterViewController(bookService: bookService, htmlWrapper: htmlWrapper, chapter: chapter)
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

