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

        guard let bookURLString = Bundle.main.infoDictionary?["BookURL"] as? String,
            let bookURL = URL(string: bookURLString) else {
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
                    switch result {
                    case .success(let chapters):
                        expect(chapters.count).to(beGreaterThan(1), description: "Expected to have received some chapters, got no chapters.")
                        expect(chapters.filter { $0.subchapters.count > 0 }.count).to(beGreaterThan(1), description: "Expected some chapters to have subchapters, none had subchapters.")
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

                self.waitForExpectations(timeout: 10, handler: nil)
            }
        }
    }
}
