import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation

@testable import SBKit

final class NetworkSyncServiceSpec: QuickSpec {
    override func spec() {
        var subject: NetworkSyncService!
        var client: URLSession!

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

        let pageURL = bookURL.appendingPathComponent("index.html", isDirectory: false)

        beforeEach {
            client = URLSession.shared
            subject = NetworkSyncService(
                httpClient: client
            )
        }

        describe("-check(url:etag:)") {
            context("with an old etag") {
                it("successfully fetches the new content and parses the data") {
                    let expectation = self.expectation(description: "CheckFuture")

                    subject.check(url: pageURL, etag: "completely invalid etag").then { result in
                        parse(result: result, expectation: expectation) { content in
                            switch content {
                            case .updateAvailable(content: let data, etag: let etag):
                                let parsedData = String(data: data, encoding: .utf8)!

                                expect(etag).toNot(equal("completely invalid etag"))

                                expect(parsedData).to(contain("</html>"))
                            default:
                                fail("Expected to have new content, got \(result)")
                            }
                        }
                    }

                    self.waitForExpectations(timeout: 10, handler: nil)
                }
            }

            context("with current content") {
                it("recognizes that it doesn't need new data") {
                    let expectation = self.expectation(description: "CheckFuture")

                    currentEtag(expectation: expectation).then { result in
                        guard let etag = result.value else { return }

                        subject.check(url: pageURL, etag: etag).then { result in
                            parse(result: result, expectation: expectation) { content in
                                expect(content).to(equal(.noNewContent))
                            }
                        }
                    }

                    self.waitForExpectations(timeout: 10, handler: nil)
                }

                func currentEtag(expectation: XCTestExpectation) -> Future<Result<String, ServiceError>> {
                    return subject.check(url: pageURL, etag: "").map { (result: Result<SyncJudgement, ServiceError>) -> Result<String, ServiceError> in
                        switch result {
                        case .success(.updateAvailable(content: _, etag: let etag)):
                            return .success(etag)
                        case .failure(let error):
                            fail("No etag received: received \(error)")
                            expectation.fulfill()
                            return .failure(error)
                        default:
                            fail("No etag received (received noNewContent)")
                            expectation.fulfill()
                            return .failure(.unknown)
                        }
                    }
                }
            }
        }
    }
}
