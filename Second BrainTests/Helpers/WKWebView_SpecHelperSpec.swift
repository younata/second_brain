import Quick
import Nimble
import WebKit

final class WKWebViewSpecHelperSpec: QuickSpec {
    override func spec() {
        var subject: WKWebView!

        beforeEach {
            subject = WKWebView()
        }

        describe("-loadHTMLString(:baseURL:)") {
            beforeEach {
                subject.loadHTMLString("my html", baseURL: nil)
            }

            it("records the string it was called with") {
                expect(subject.lastHTMLStringLoaded).to(equal("my html"))
            }
        }

        describe("-load(:)") {
            let request = URLRequest(url: URL(string: "https://example.com")!)
            beforeEach {
                subject.load(request)
            }

            it("records the request it was last called with") {
                expect(subject.lastRequestLoaded).to(equal(request))
            }
        }

        describe("currentURL") {
            it("changes what the webview's url is") {
                expect(subject.url).to(beNil())

                subject.currentURL = URL(string: "https://example.com")

                expect(subject.url).to(equal(URL(string: "https://example.com")))
            }
        }
    }
}
