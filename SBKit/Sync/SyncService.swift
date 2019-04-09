import Result
import CBGPromise
import FutureHTTP

enum SyncJudgement: Equatable {
    case updateAvailable(content: Data, etag: String)
    case noNewContent
}

protocol SyncService {
    func check(url: URL, etag: String) -> Future<Result<SyncJudgement, ServiceError>>
}

struct NetworkSyncService: SyncService {
    let httpClient: HTTPClient

    func check(url: URL, etag: String) -> Future<Result<SyncJudgement, ServiceError>> {
        var request = URLRequest(url: url)
        request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return self.httpClient.request(request).map { result -> Result<SyncJudgement, ServiceError> in
            switch result {
            case .success(let response):
                return response.map(expectedStatuses: [.ok, .notModified]).flatMap(self.judge)
            case .failure:
                return .failure(.unknown)
            }
        }
    }

    private func judge(response: HTTPResponse, status: HTTPStatus) -> Result<SyncJudgement, ServiceError> {
        switch status {
        case .ok:
            guard let etag = self.etagHeader(response: response) else {
                return .failure(.parse)
            }
            return .success(.updateAvailable(content: response.body, etag: etag))
        case .notModified:
            return .success(.noNewContent)
        default:
            return .failure(.unknown)
        }
    }

    private func etagHeader(response: HTTPResponse) -> String? {
        return response.headers["ETag"] ?? response.headers["Etag"] ?? response.headers["etag"]
    }
}
