import SBKit
import Swinject
import SwinjectStoryboard

func register(_ container: Container) {
    let bookURL = URL(string: "https://knowledge.rachelbrindle.com")!

    container.register(BookService.self) { r in
        return r.resolve(BookService.self, argument: bookURL)!
    }

    container.register(HTMLWrapper.self) { _ in
        return BundleHTMLWrapper()
    }.inObjectScope(.container)

    container.register(ChapterSelectorPubSub.self) { _ in
        return ChapterSelectorPubSub()
    }.inObjectScope(.container)

    container.storyboardInitCompleted(ChapterTreeViewController.self) { r, c in
        c.bookService = r.resolve(BookService.self)
        c.selectionPublisher = r.resolve(ChapterSelectorPubSub.self)
    }

    container.storyboardInitCompleted(ChapterViewController.self) { r, c in
        c.bookService = r.resolve(BookService.self)
        c.activityService = r.resolve(ActivityService.self)
        c.htmlWrapper = r.resolve(HTMLWrapper.self)
        c.chapterSelectionPublisher = r.resolve(ChapterSelectorPubSub.self)
    }
}
