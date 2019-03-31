import Quick
import Nimble
import FutureHTTP

public func haveReceivedRequest(_ request: URLRequest) -> Predicate<FakeHTTPClient> {
    return Predicate.define("have made request <\(stringify(request))>") { actualExpression, message in
        guard let client = try actualExpression.evaluate() else {
            return PredicateResult(status: .fail, message: message.appendedBeNilHint())
        }
        return PredicateResult(bool: client.requests.contains(request), message: message)
    }
}

final class HaveReceivedRequestSpec: QuickSpec {
    override func spec() {
        var subject: FakeHTTPClient!

        beforeEach {
            subject = FakeHTTPClient()
        }

        it("fails when the client hasn't made any requests") {
            expect(subject).toNot(haveReceivedRequest(URLRequest(url: URL(string: "https://example.com")!)))
        }

        it("succeeds when the client has made a request to that url and that method") {
            _ = subject.request(URLRequest(url: URL(string: "https://example.com")!))

            expect(subject).to(haveReceivedRequest(URLRequest(url: URL(string: "https://example.com")!)))
        }

        it("fails when the url is correct, but not the other parts of the request") {
            var request = URLRequest(url: URL(string: "https://example.com")!)
            request.httpMethod = "PUT"
            _ = subject.request(request)

            expect(subject).toNot(haveReceivedRequest(URLRequest(url: URL(string: "https://example.com")!)))
        }
    }
}
