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

    public var localizedDescription: String {
        switch self {
        case .parse:
            return NSLocalizedString("Unable to parse response", comment: "")
        case .cache:
            return NSLocalizedString("Error fetching from cache", comment: "")
        case .notFound:
            return NSLocalizedString("Unable to find repository contents", comment: "")
        case .unknown:
            return NSLocalizedString("Unknown error, try again later", comment: "")
        case .network(let error):
            return error.localizedDescription
        }
    }

    public var title: String {
        return NSLocalizedString("You might want to look into this", comment: "")
    }
}

public enum NetworkError: Error, Equatable {
    case http(HTTPStatus?)

    public var localizedDescription: String {
        switch self {
        case .http(let status):
            guard let nonNilStatus = status else {
                return NSLocalizedString("Did not receive http status in response", comment: "")
            }

            return "Received HTTP \(nonNilStatus.rawValue)"
        }
    }
}
