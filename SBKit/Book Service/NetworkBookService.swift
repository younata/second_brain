import Kanna
import Result
import CBGPromise
import FutureHTTP

struct NetworkBookService: BookService {
    let client: HTTPClient
    let queueJumper: OperationQueueJumper
    let bookURL: URL

    private var apiURL: URL { return self.bookURL.appendingPathComponent("api", isDirectory: true) }

    func book() -> Future<Result<Book, ServiceError>> {
        let bookJsonURL = self.apiURL.appendingPathComponent("book.json", isDirectory: false)

        return self.queueJumper.jump(self.client.request(URLRequest(url: bookJsonURL)).map { result -> Result<Book, ServiceError> in
            switch result {
            case .success(let response):
                return response.map(expectedStatus: .ok).flatMap {
                    return parseBook(data: $0.body, bookURL: self.bookURL)
                }
            case .failure:
                return .failure(.unknown)
            }
        })
    }

    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>> {
        return self.queueJumper.jump(self.client.request(URLRequest(url: chapter.contentURL)).map { result -> Result<String, ServiceError> in
            switch result {
            case .success(let response):
                return response.map(expectedStatus: .ok).flatMap {
                    return parseChapterContent(data: $0.body, url: self.bookURL)
                }
            case .failure:
                return .failure(.unknown)
            }
        })
    }
}
