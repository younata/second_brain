import SBKit
import Result
import CBGPromise

final class FakeBookService: BookService {
    private(set) var chaptersPromises: [Promise<Result<[Chapter], ServiceError>>] = []
    func chapters() -> Future<Result<[Chapter], ServiceError>> {
        let promise = Promise<Result<[Chapter], ServiceError>>()
        self.chaptersPromises.append(promise)
        return promise.future
    }

    private(set) var titlePromises: [Promise<Result<String, ServiceError>>] = []
    func title() -> Future<Result<String, ServiceError>> {
        let promise = Promise<Result<String, ServiceError>>()
        self.titlePromises.append(promise)
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
}
