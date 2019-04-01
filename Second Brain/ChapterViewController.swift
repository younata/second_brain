import SBKit
import UIKit
import WebKit

class ChapterViewController: UIViewController {
    private let bookService: BookService
    private let chapter: Chapter

    @IBOutlet weak var warningView: WarningView!
    @IBOutlet weak var webView: WKWebView!

    init(bookService: BookService, chapter: Chapter) {
        self.bookService = bookService
        self.chapter = chapter

        super.init(nibName: "ChapterViewController", bundle: Bundle.main)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
