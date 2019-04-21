import Cocoa
import SBKit

class ChapterTreeViewController: NSViewController {
    @IBOutlet weak var treeController: NSTreeController!

    var bookService: BookService? {
        didSet {
            guard self.isViewLoaded else { return }
            self.refresh()
        }
    }

    @objc dynamic var contents: [AnyObject] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refresh()
    }

    @objc func refresh() {
        self.bookService?.book().then { result in
            switch result {
            case .success(let book):
                self.show(book: book)
            case .failure(let error):
                self.show(error: error)
            }
        }
    }

    private func show(book: Book) {
        print("displaying book")
        self.view.window?.title = book.title
        self.title = book.title
        self.contents = book.chapters.map(CocoaChapter.init)
    }

    private func show(error: ServiceError) {
        let alert = NSAlert(error: error)
        alert.messageText = error.title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
