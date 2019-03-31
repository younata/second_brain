import SBKit
import Swinject

func register(_ container: Container) {
    container.register(ChapterViewController.self) { (r: Resolver, url: URL) in
        return ChapterViewController(
            bookService: r.resolve(BookService.self, argument: url)!
        )
    }
}
