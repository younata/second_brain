import Quick
import UIKit
import Nimble

@testable import Second_Brain
@testable import SBKit

final class ChapterViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ChapterViewController!

        var bookService: FakeBookService!

        let chapter = Chapter(title: "My Title", contentURL: URL(string: "https://example.com/chapter.html")!, subchapters: [])

        beforeEach {
            bookService = FakeBookService()

            subject = ChapterViewController(bookService: bookService, chapter: chapter)
        }

        describe("when the view loads") {
            beforeEach {
                subject.view.layoutIfNeeded()
            }
        }
    }
}

