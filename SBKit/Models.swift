import FutureHTTP

public struct Chapter: Equatable {
    public let title: String
    public let contentURL: URL
    public let subchapters: [Chapter]
}

public struct Book: Equatable {
    public let title: String
    public let chapters: [Chapter]
}

public enum ServiceError: Error, Equatable {
    case parse
    case unknown
    case cache
    case notFound
    case network(NetworkError)
}

public enum NetworkError: Error, Equatable {
    case http(HTTPStatus?)
}
