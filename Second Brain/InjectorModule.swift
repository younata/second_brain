import SBKit
import Swinject

func register(_ container: Container) {
    container.register(ChapterListViewController.self) { (r: Resolver, url: URL) in
        return ChapterListViewController(
            bookService: r.resolve(BookService.self, argument: url)!,
            chapterViewControllerFactory: { chapter in
                return r.resolve(ChapterViewController.self, arguments: url, chapter)!
            }
        )
    }

    container.register(ChapterViewController.self) { (r: Resolver, url: URL, chapter: Chapter) in
        return ChapterViewController(
            bookService: r.resolve(BookService.self, argument: url)!,
            chapter: chapter
        )
    }
}
