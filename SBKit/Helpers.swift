import Kanna
import Result
import CBGPromise
import FutureHTTP

private struct JSONBook: Decodable, Equatable {
    let title: String
    let chapters: [JSONChapter]
}

private struct JSONChapter: Decodable, Equatable {
    let path: String
    let title: String
    let subchapters: [JSONChapter]
}

func parseBook(data: Data, bookURL: URL) -> Result<Book, ServiceError> {
    let jsonBook: JSONBook
    do {
        let decoder = JSONDecoder()
        jsonBook = try decoder.decode(JSONBook.self, from: data)
    } catch let error {
        dump(error)
        return .failure(.parse)
    }
    let book = Book(
        title: jsonBook.title,
        chapters: jsonBook.chapters.map { return Chapter($0, baseURL: bookURL) }
    )
    return .success(book)
}

func parseChapterContent(data: Data, url: URL) -> Result<String, ServiceError> {
    guard let doc = try? HTML(html: data, url: url.absoluteString, encoding: .utf8) else {
        return .failure(.parse)
    }
    if let content = doc.css("main").first?.innerHTML {
        return .success(content)
    }
    return .failure(.parse)
}

extension Chapter {
    fileprivate init(_ bookChapter: JSONChapter, baseURL: URL) {
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

    func map(expectedStatuses: Set<HTTPStatus>) -> Result<(HTTPResponse, HTTPStatus), ServiceError> {
        guard let status = self.status, expectedStatuses.contains(status) else {
            return .failure(.network(.http(self.status)))
        }
        return .success((self, status))
    }
}

extension Future {
    public class func resolved<T>(_ value: T) -> Future<T> {
        let promise = Promise<T>()
        promise.resolve(value)
        return promise.future
    }
}

extension Result where Result.Error: Swift.Error {
    public func mapFuture<U>(_ transform: (Value) -> Future<Result<U, Error>>) -> Future<Result<U, Error>> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return Future<Result<U, Error>>.resolved(Result<U, Error>.failure(error))
        }
    }
}
