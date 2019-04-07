import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation_PivotalSpecHelper

@testable import SBKit

func itBehavesLikeResolvingWithAnError<T>(factory: @escaping () -> (FakeHTTPClient, PSHKFakeOperationQueue?, Future<Result<T, ServiceError>>)) {
    context("when the request succeeds without actually succeeding") {
        var client: FakeHTTPClient!
        var queue: PSHKFakeOperationQueue?
        var future: Future<Result<T, ServiceError>>!
        beforeEach {
            let items = factory()
            client = items.0
            queue = items.1
            future = items.2
        }
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
                queue?.runNextOperation()
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
                queue?.runNextOperation()
                expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                expect(future.value?.error).to(equal(.network(.http(.internalServerError))))
            }
        }
    }
}
