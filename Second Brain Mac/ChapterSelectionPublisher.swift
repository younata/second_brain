import SBKit

protocol ChapterSelectionSubscriber: class {
    func didSelect(chapter: Chapter)
}

final class ChapterSelector: NSObject {
    private weak var subscriber: ChapterSelectionSubscriber?

    init(subscriber: ChapterSelectionSubscriber) {
        self.subscriber = subscriber
    }

    func didSelect(chapter: Chapter) {
        self.subscriber?.didSelect(chapter: chapter)
    }
}

final class ChapterSelectorPubSub {
    private var subscribers: [ChapterSelector] = []

    func add(subscriber: ChapterSelectionSubscriber) {
        self.subscribers.append(ChapterSelector(subscriber: subscriber))
    }

    func select(chapter: Chapter) {
        self.subscribers.forEach { $0.didSelect(chapter: chapter) }
    }
}
