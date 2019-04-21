import SBKit
import Swinject
import SwinjectStoryboard

func register(_ container: Container) {
    let bookURL = URL(string: "https://knowledge.rachelbrindle.com")!

    container.register(BookService.self) { r in
        return r.resolve(BookService.self, argument: bookURL)!
    }

    container.storyboardInitCompleted(ChapterTreeViewController.self) { r, c in
        c.bookService = r.resolve(BookService.self)
    }
}
