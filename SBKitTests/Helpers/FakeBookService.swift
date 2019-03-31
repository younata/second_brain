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
}
