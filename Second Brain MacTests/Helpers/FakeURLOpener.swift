@testable import Second_Brain

final class FakeURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []
    @discardableResult func open(_ url: URL) -> Bool {
        self.openedURLs.append(url)
        return true
    }
}
