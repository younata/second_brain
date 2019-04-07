import Quick
import Nimble
import Result

@testable import SBKit

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
