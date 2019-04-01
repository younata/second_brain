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

        let url = self.chapter.contentURL

        self.title = self.chapter.title

        self.bookService.content(of: self.chapter).then { result in
            switch result {
            case .success(let content):
                self.display(html: content, url: url)
            case .failure(ServiceError.network(.http)):
                self.warningView.show(text: NSLocalizedString("Unable to get chapter content, check the server", comment: ""))
            default:
                self.warningView.show(text: NSLocalizedString("Error fetching chapter: Try again later", comment: ""))
            }
        }
    }

    private func display(html: String, url: URL) {
        self.webView.loadHTMLString("<html><body>\(html)</body></html>", baseURL: url)
    }
}
