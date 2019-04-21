import Cocoa
import SBKit

class ChapterTreeViewController: NSViewController {
    @IBOutlet weak var treeController: NSTreeController! {
        willSet {
            if newValue == nil {
                self.selectedIndexPathChange = nil
            }
        }
    }

    var bookService: BookService?
    var selectionPublisher: ChapterSelectorPubSub?

    @objc dynamic var contents: [CocoaChapter] = []

    private var selectedIndexPathChange: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refresh()

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
        self.bookService?.book().then { [weak self] result in
            switch result {
            case .success(let book):
                self?.show(book: book)
            case .failure(let error):
                self?.show(error: error)
            }
        }
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
