import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation

@testable import SBKit

final class NetworkBookServiceSpec: QuickSpec {
    override func spec() {
        var subject: NetworkBookService!
        var client: URLSession!
        var queueJumper: OperationQueueJumper!

        guard let bookURLString = Bundle(for: self.classForCoder).infoDictionary?["BookURL"] as? String else {
            it("is missing the BookURL") {
                fail("Unable to get BookURL from SBKitIntegrationTest's info.plist")
            }
            return
        }

        guard let bookURL = URL(string: bookURLString) else {
            it("is improperly configured") {
                fail("Unable to convert bookURLString to a url, got \(bookURLString)")
            }
            return
        }

        beforeEach {
            client = URLSession.shared
            queueJumper = OperationQueueJumper(queue: .main)
            subject = NetworkBookService(
                client: client,
                queueJumper: queueJumper,
                bookURL: bookURL
            )
        }

        describe("-book()") {
            it("successfully fetches from the network and parses the data") {
                let expectation = self.expectation(description: "ChaptersFuture")

                subject.book().then { result in
                    parse(result: result, expectation: expectation) { book in
                        expect(book.title).to(equal("Knowledge Repository"))
                        expect(book.chapters.count).to(beGreaterThan(1), description: "Expected to have received some chapters, got no chapters.")
                        expect(book.chapters.filter { $0.subchapters.count > 0 }.count).to(beGreaterThan(1), description: "Expected some chapters to have subchapters, none had subchapters.")
                    }
                }

                self.waitForExpectations(timeout: 10, handler: nil)
            }
        }

        describe("-content(of:)") {
            it("successfully fetches from the network and parses the content") {
                let expectation = self.expectation(description: "ContentFuture")

                let chapter = Chapter(title: "", contentURL: bookURL.appendingPathComponent("astronomy/index.html"), subchapters: [])

                subject.content(of: chapter).then { result in
                    parse(result: result, expectation: expectation) { content in
                        expect(content).to(contain("Equatorial Mount"))
                    }
                }

                self.waitForExpectations(timeout: 10, handler: nil)
            }
        }
    }
}
