import Cocoa
import Result
import SBKit
import CBGPromise

class ChapterTreeViewController: NSViewController {
    @IBOutlet weak var treeController: NSTreeController! {
        willSet {
            if newValue == nil {
                self.selectedIndexPathChange = nil
            }
        }
    }

    var bookService: BookService? {
        didSet {
            self.refresh()
        }
    }
    var selectionPublisher: ChapterSelectorPubSub?

    private var bookFuture: Future<Result<Book, ServiceError>>?

    @objc dynamic var contents: [CocoaChapter] = []

    private var selectedIndexPathChange: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.selectedIndexPathChange = self.treeController.observe(\.selectedNodes) { _, _ in
            guard let node = self.treeController.selectedNodes.first else {
                return
            }
            guard let chapter = (node.representedObject as? CocoaChapter)?.chapter else {
                print("Node.representedObject is not a CocoaChapter, it is:")
                dump(node.representedObject)
                return
            }
            self.selectionPublisher?.select(chapter: chapter)
        }
    }

    func refresh() {
        self.bookFuture = self.bookService?.book().then { [weak self] result in
            switch result {
            case .success(let book):
                self?.show(book: book)
            case .failure(let error):
                self?.show(error: error)
            }
        }
    }

    func resumeFromActivity(url: URL) -> Bool {
        guard let bookResult = self.bookFuture?.value else {
            self.bookFuture?.then { [weak self] (bookResult: Result<Book, ServiceError>) in
                self?.presentChapter(with: url, and: bookResult, showError: true)
            }
            return true
        }
        return self.presentChapter(with: url, and: bookResult, showError: false)
    }

    @discardableResult
    private func presentChapter(with url: URL, and result: Result<Book, ServiceError>, showError: Bool) -> Bool {
        let error: ServiceError
        switch result {
        case .success(let book):
            if let chapter = book.flatChapters.first(where: { $0.contentURL == url }) {
                self.selectionPublisher?.select(chapter: chapter)
                return true
            }
            error = ServiceError.notFound
        case .failure(let receivedError):
            error = receivedError
        }

        if showError {
            self.show(error: error)
        }
        return false
    }

    private func show(book: Book) {
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
