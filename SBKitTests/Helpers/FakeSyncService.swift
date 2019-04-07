import Result
import CBGPromise

@testable import SBKit

final class FakeSyncService: SyncService {
    private(set) var checkCalls: [(url: URL, etag: String)] = []
    private(set) var checkPromises: [Promise<Result<SyncJudgement, ServiceError>>] = []
    func check(url: URL, etag: String) -> Future<Result<SyncJudgement, ServiceError>> {
        self.checkCalls.append((url, etag))
        let promise = Promise<Result<SyncJudgement, ServiceError>>()
        self.checkPromises.append(promise)
        return promise.future
    }
}
