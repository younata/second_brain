import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import SBKit

final class NetworkSyncServiceSpec: QuickSpec {
    override func spec() {
        var subject: NetworkSyncService!

        var httpClient: FakeHTTPClient!

        beforeEach {
            httpClient = FakeHTTPClient()

            subject = NetworkSyncService(httpClient: httpClient)
        }

        describe("check(url:etag:)") {
            var future: Future<Result<SyncJudgement, ServiceError>>!

            let url = URL(string: "https://example.com/whatever")!
            let originalEtag = "my_etag"

            beforeEach {
                future = subject.check(url: url, etag: originalEtag)
            }

            it("makes a GET request to the url, with an If-None-Match for the etag") {
                var expectedRequest = URLRequest(url: url)
                expectedRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                // Needed to ignore the iOS-specific cache policy, see https://stackoverflow.com/questions/35608051/etag-and-if-none-match-http-headers-are-not-working/39341847
                expectedRequest.addValue(originalEtag, forHTTPHeaderField: "If-None-Match")

                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient).to(haveReceivedRequest(expectedRequest))
            }

            describe("when the request succeeds") {
                context("with http 200 (new data)") {
                    beforeEach {
                        let response = HTTPResponse(
                            body: "<html><body></body></html>".data(using: .utf8)!,
                            status: .ok,
                            mimeType: "text/html",
                            headers: ["ETag": "my_new_etag"]
                        )
                        httpClient.requestPromises.last?.resolve(.success(response))
                    }

                    it("resolves the future with .updateAvailable with the data and the new etag.") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(equal(.updateAvailable(
                            content: "<html><body></body></html>".data(using: .utf8)!,
                            etag: "my_new_etag"
                        )))
                    }
                }

                context("with http 304 (no new data)") {
                    beforeEach {
                        let response = HTTPResponse(
                            body: Data(),
                            status: .notModified,
                            mimeType: "",
                            headers: ["ETag": originalEtag]
                        )

                        httpClient.requestPromises.last?.resolve(.success(response))
                    }

                    it("resolves the future with .noNewContent") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(equal(.noNewContent))
                    }
                }
            }

            itBehavesLikeResolvingWithAnError { return (httpClient, nil, future) }
        }
    }
}
