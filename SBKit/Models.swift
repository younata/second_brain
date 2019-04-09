import FutureHTTP

public struct Chapter: Equatable, Hashable {
    public let title: String
    public let contentURL: URL
    public let subchapters: [Chapter]
}

public struct Book: Equatable {
    public let title: String
    public let chapters: [Chapter]

    public var flatChapters: [Chapter] {
        var chaptersToReturn = self.chapters
        var chaptersToIterate = chaptersToReturn
        while !chaptersToIterate.isEmpty {
            guard let chapter = chaptersToIterate.popLast() else {
                break
            }
            chaptersToReturn += chapter.subchapters
            chaptersToIterate += chapter.subchapters
        }
        return chaptersToReturn
    }
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
