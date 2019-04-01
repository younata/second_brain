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

        describe("-chapters()") {
            it("successfully fetches from the network and parses the data") {
                let expectation = self.expectation(description: "ChaptersFuture")

                subject.chapters().then { result in
                    parse(result: result, expectation: expectation) { chapters in
                        expect(chapters.count).to(beGreaterThan(1), description: "Expected to have received some chapters, got no chapters.")
                        expect(chapters.filter { $0.subchapters.count > 0 }.count).to(beGreaterThan(1), description: "Expected some chapters to have subchapters, none had subchapters.")
                    }
                }

                self.waitForExpectations(timeout: 10, handler: nil)
            }
        }

        describe("-title()") {
            it("successfully fetches from the network and parses the title") {
                let expectation = self.expectation(description: "TitleFuture")

                subject.title().then { result in
                    parse(result: result, expectation: expectation) { title in
                        expect(title).to(equal("Knowledge Repository"))
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

        func parse<T>(result: Result<T, ServiceError>, expectation: XCTestExpectation, callback: (T) -> Void) {
            switch result {
            case .success(let value):
                callback(value)
            case .failure(.parse):
                fail("Ran into issue parsing the returned contents")
            case .failure(.network(.http(let status))):
                fail("Received http error \(String(describing: status)) trying to receive data")
            default:
                print("Received error, but it's likely spurious")
                print("contents are: \(String(describing: result.error))")
            }
            expectation.fulfill()
        }
    }
}
