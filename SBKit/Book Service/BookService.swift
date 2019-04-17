import Result
import CBGPromise

public protocol BookService {
    func book() -> Future<Result<Book, ServiceError>>
    func content(of chapter: Chapter) -> Future<Result<String, ServiceError>>
}

protocol BookServiceDelegate {
    func didRemove(chapter: Chapter)
}
