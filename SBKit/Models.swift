import FutureHTTP
import Foundation

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

public struct BookServiceNotification {
    public static let didFetchBook = Notification.Name(rawValue: "BookServiceDidFetchBook")
    public static let didFetchChapterContent = Notification.Name(rawValue: "BookServiceDidFetchChapterContent")

    public let totalParts: Int
    public let completedParts: Int
    public let errorMessage: String?

    public var isFinished: Bool {
        return self.totalParts == self.completedParts
    }

    public init?(notification: Notification) {
        let bookNotes: [Notification.Name] = [
            BookServiceNotification.didFetchBook,
            BookServiceNotification.didFetchChapterContent
        ]
        guard bookNotes.contains(notification.name),
            let total = notification.userInfo?["total"] as? Int,
            let completed = notification.userInfo?["completed"] as? Int
            else { return nil }

        self.totalParts = total
        self.completedParts = completed
        self.errorMessage = notification.userInfo?["error"] as? String
    }

    internal init(total: Int, completed: Int, errorMessage: String?) {
        self.totalParts = total
        self.completedParts = completed
        self.errorMessage = errorMessage
    }

    internal func bookNotification() -> Notification {
        return self.notification(name: BookServiceNotification.didFetchBook)
    }

    internal func chapterNotification() -> Notification {
        return self.notification(name: BookServiceNotification.didFetchChapterContent)
    }

    private func notification(name: Notification.Name) -> Notification {
        var info: [String: Any] = [
            "total": self.totalParts,
            "completed": self.completedParts
        ]
        if let error = self.errorMessage {
            info["error"] = error
        }
        return Notification(
            name: name,
            object: nil,
            userInfo: info
        )
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
