import Nimble
@testable import SBKit

final class FakeSearchIndexService: SearchIndexService {
    private(set) var updateCalls: [(chapter: Chapter, content: String)] = []
    func update(chapter: Chapter, content: String) {
        self.updateCalls.append((chapter, content))
    }

    private(set) var endRefreshingCallCount: Int = 0
    func endRefresh() {
        self.endRefreshingCallCount += 1
    }
}
