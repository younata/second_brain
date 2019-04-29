@testable import SBKit
import Result
import CBGPromise

final class FakeBookService: BookService {
    private(set) var bookPromises: [Promise<Result<Book, ServiceError>>] = []
    func book() -> Future<Result<Book, ServiceError>> {
        let promise = Promise<Result<Book, ServiceError>>()
        self.bookPromises.append(promise)
        return promise.future
    }

    private(set) var contentsCalls: [Chapter] = []
    private(set) var contentsPromises: [Promise<Result<String, ServiceError>>] = []
    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        self.contentsCalls.append(chapter)
        let promise = Promise<Result<String, ServiceError>>()
        self.contentsPromises.append(promise)
        return promise.future
    }

    func reset() {
        self.bookPromises = []

        self.contentsCalls = []
        self.contentsPromises = []
    }
}
