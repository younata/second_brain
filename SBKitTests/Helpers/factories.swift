@testable import SBKit

func chapterFactory(title: String = "Title", contentURL: URL = URL(string: "https://example.com")!, subchapters: [Chapter] = []) -> Chapter {
    return Chapter(title: title, contentURL: contentURL, subchapters: subchapters)
}
