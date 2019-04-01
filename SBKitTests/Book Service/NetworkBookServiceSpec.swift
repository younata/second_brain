import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation_PivotalSpecHelper

@testable import SBKit

final class NetworkBookServiceSpec: QuickSpec {
    override func spec() {
        var subject: NetworkBookService!
        var client: FakeHTTPClient!
        var queueJumper: OperationQueueJumper!
        var queue: PSHKFakeOperationQueue!

        let bookURL = URL(string: "https://example.com")!

        beforeEach {
            client = FakeHTTPClient()

            queue = PSHKFakeOperationQueue()
            queueJumper = OperationQueueJumper(queue: queue)

            subject = NetworkBookService(
                client: client,
                queueJumper: queueJumper,
                bookURL: bookURL
            )
        }

        func page(_ path: String) -> URL {
            return bookURL.appendingPathComponent(path)
        }

        func itBehavesLikeResolvingWithAnError<T>(futureFactory: @escaping () -> Future<Result<T, ServiceError>>) {
            context("when the request succeeds without actually succeeding") {
                context("with an http 400-level error") {
                    beforeEach {
                        client.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "Bad Data".data(using: .utf8)!,
                            status: .badRequest,
                            mimeType: "text/plain",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with a failure") {
                        queue.runNextOperation()
                        let future = futureFactory()
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.network(.http(.badRequest))))
                    }
                }

                context("with an http 500-level error") {
                    beforeEach {
                        client.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "Bad Data".data(using: .utf8)!,
                            status: .internalServerError,
                            mimeType: "text/plain",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with a failure") {
                        queue.runNextOperation()
                        let future = futureFactory()
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.network(.http(.internalServerError))))
                    }
                }
            }
        }

        describe("-chapters()") {
            var future: Future<Result<[Chapter], ServiceError>>!

            beforeEach {
                future = subject.chapters()
            }

            it("makes a GET request to the bookURL's chapters api endpoint") {
                expect(client.requests).to(haveCount(1))
                expect(client).to(haveReceivedRequest(URLRequest(url: bookURL.appendingPathComponent("api/chapters.json", isDirectory: false))))
            }

            describe("when the request succeeds with http 200") {
                let chapters: [[String: Any]] = [
                    ["path": "/index.html", "title": "Introduction", "subchapters": []],
                    ["path": "/ci/index.html", "title": "Continuous Integration", "subchapters": [
                        ["path": "/ci/concourse.html", "title": "Concourse", "subchapters": []]
                    ]],
                    ["path": "/food/index.html", "title": "Food", "subchapters": [
                        ["path": "/food/recipes/index.html", "title": "Recipes", "subchapters": [
                            ["path": "/food/recipes/mac_and_cheese.html", "title": "Mac and Cheese", "subchapters": []],
                            ["path": "/food/recipes/soup.html", "title": "Simple Soup", "subchapters": []]
                        ]]
                    ]],
                    ["path": "/rust/index.html", "title": "Rust", "subchapters": []]
                ]
                beforeEach {
                    guard let jsonChapters = try? JSONSerialization.data(withJSONObject: chapters, options: []) else {
                        fail("Unable to serialize chapters")
                        return
                    }
                    client.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: jsonChapters,
                        status: .ok,
                        mimeType: "text/html",
                        headers: [:]
                    )))
                    queue.runNextOperation()
                }

                it("resolves the future with the parsed chapters") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(beNil())
                    expect(future.value?.value).to(equal([
                        Chapter(title: "Introduction", contentURL: page("index.html"), subchapters: []),
                        Chapter(title: "Continuous Integration", contentURL: page("ci/index.html"), subchapters: [
                            Chapter(title: "Concourse", contentURL: page("ci/concourse.html"), subchapters: [])
                        ]),
                        Chapter(title: "Food", contentURL: page("food/index.html"), subchapters: [
                            Chapter(title: "Recipes", contentURL: page("food/recipes/index.html"), subchapters: [
                                Chapter(title: "Mac and Cheese", contentURL: page("food/recipes/mac_and_cheese.html"), subchapters: []),
                                Chapter(title: "Simple Soup", contentURL: page("food/recipes/soup.html"), subchapters: []),
                            ])
                        ]),
                        Chapter(title: "Rust", contentURL: page("rust/index.html"), subchapters: [])
                    ]))
                }
            }

            itBehavesLikeResolvingWithAnError { return future }
        }

        describe("-title()") {
            var future: Future<Result<String, ServiceError>>!

            beforeEach {
                future = subject.title()
            }

            it("makes a GET request to the bookURL") {
                expect(client.requests).to(haveCount(1))
                expect(client).to(haveReceivedRequest(URLRequest(url: bookURL)))
            }

            describe("when the request succeeds with http 200") {
                beforeEach {
                    guard let url = Bundle(for: self.classForCoder).url(forResource: "index", withExtension: "html") else {
                        fail("Unable to get url for book's index.html")
                        return
                    }
                    guard let data = try? Data(contentsOf: url) else {
                        fail("Unable to read contents of index.html")
                        return
                    }

                    client.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: data,
                        status: .ok,
                        mimeType: "text/html",
                        headers: [:]
                    )))
                    queue.runNextOperation()
                }

                it("resolves the future with the parsed title") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(beNil())
                    expect(future.value?.value).to(equal("Book Title"))
                }
            }

            itBehavesLikeResolvingWithAnError { return future }
        }

        describe("-content(of:)") {
            var future: Future<Result<String, ServiceError>>!

            let chapter = Chapter(title: "", contentURL: URL(string: "https://example.com/foo.html")!, subchapters: [])

            beforeEach {
                future = subject.content(of: chapter)
            }

            it("makes a GET request to the chapter's url") {
                expect(client.requests).to(haveCount(1))
                expect(client).to(haveReceivedRequest(URLRequest(url: chapter.contentURL)))
            }

            describe("when the request succeeds with http 200") {
                beforeEach {
                    guard let url = Bundle(for: self.classForCoder).url(forResource: "index", withExtension: "html") else {
                        fail("Unable to get url for book's index.html")
                        return
                    }
                    guard let data = try? Data(contentsOf: url) else {
                        fail("Unable to read contents of index.html")
                        return
                    }

                    client.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: data,
                        status: .ok,
                        mimeType: "text/html",
                        headers: [:]
                    )))
                    queue.runNextOperation()
                }

                it("resolves the future with the parsed title") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(beNil())
                    guard let value = future.value?.value else { return }

                    let expectedContent = """
<a class="header" href="#introduction" id="introduction"><h1>Introduction</h1></a>
<p>Some Content</p>
<p>Another paragraph of content</p>
""".trimmingCharacters(in: .whitespacesAndNewlines)

                    expect(value.trimmingCharacters(in: .whitespacesAndNewlines)).to(equal(expectedContent))
                }
            }

            itBehavesLikeResolvingWithAnError { return future }
        }
    }
}
