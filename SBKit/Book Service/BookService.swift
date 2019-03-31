import Result
import CBGPromise
import FutureHTTP

public struct Book: Equatable {
    public let title: String
    public let url: URL
    public let chapters: [Chapter]
}

public struct Chapter: Equatable {
    public let title: String
    public let contentURL: URL
    public let subchapters: [Chapter]
}

public enum ServiceError: Error, Equatable {
    case parse
    case unknown
    case network(NetworkError)
}

public enum NetworkError: Error, Equatable {
    case http(HTTPStatus?)
}

public protocol BookService {
    func chapters() -> Future<Result<[Chapter], ServiceError>>
}

struct NetworkBookService: BookService {
    let client: HTTPClient
    let queueJumper: OperationQueueJumper
    let bookURL: URL

    private var apiURL: URL { return self.bookURL.appendingPathComponent("api", isDirectory: true) }

    func chapters() -> Future<Result<[Chapter], ServiceError>> {
        let chaptersURL = self.apiURL.appendingPathComponent("chapters.json", isDirectory: false)

        return self.queueJumper.jump(self.client.request(URLRequest(url: chaptersURL)).map { result -> Result<[Chapter], ServiceError> in
            switch result {
            case .success(let response):
                return response.map(expectedStatus: .ok).flatMap {
                    return self.parseChapters(data: $0.body)
                }
            case .failure:
                return .failure(.unknown)
            }
        })
    }

    private func parseChapters(data: Data) -> Result<[Chapter], ServiceError> {
        let bookChapters: [BookChapter]
        do {
            let decoder = JSONDecoder()
            bookChapters = try decoder.decode(Array<BookChapter>.self, from: data)
        } catch let error {
            dump(error)
            return .failure(.parse)
        }
        return .success(bookChapters.map { return Chapter($0, baseURL: self.bookURL) })
    }
}

private struct BookChapter: Decodable, Equatable {
    let path: String
    let title: String
    let subchapters: [BookChapter]
}

extension Chapter {
    fileprivate init(_ bookChapter: BookChapter, baseURL: URL) {
        self.init(
            title: bookChapter.title,
            contentURL: baseURL.appendingPathComponent(bookChapter.path),
            subchapters: bookChapter.subchapters.map { Chapter($0, baseURL: baseURL) }
        )
    }
}

extension HTTPResponse {
    func map(expectedStatus: HTTPStatus) -> Result<HTTPResponse, ServiceError> {
        guard self.status == expectedStatus else {
            return .failure(.network(.http(self.status)))
        }
        return .success(self)
    }
}
