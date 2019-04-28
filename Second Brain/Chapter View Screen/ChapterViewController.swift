import SBKit
import UIKit
import WebKit

class ChapterViewController: UIViewController {
    private let bookService: BookService
    private let htmlWrapper: HTMLWrapper
    private let activityService: ActivityService
    private let chapter: Chapter

    @IBOutlet weak var warningView: WarningView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var progressBar: UIProgressView!

    private var progressObserver: NSKeyValueObservation?

    init(bookService: BookService, htmlWrapper: HTMLWrapper, activityService: ActivityService, chapter: Chapter) {
        self.bookService = bookService
        self.htmlWrapper = htmlWrapper
        self.activityService = activityService
        self.chapter = chapter

        super.init(nibName: "ChapterViewController", bundle: Bundle.main)

        self.userActivity = self.activityService.activity(for: chapter)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = self.chapter.contentURL

        self.title = self.chapter.title

        self.progressObserver = self.webView.observe(\.estimatedProgress, options: [.new]) { _, _ in
            self.progressBar.progress = Float(self.webView.estimatedProgress)
        }

        self.webView.navigationDelegate = self

        self.bookService.content(of: self.chapter).then { [weak self] result in
            switch result {
            case .success(let content):
                self?.display(html: content, url: url)
            case .failure(ServiceError.network(.http)):
                self?.warningView.show(text: NSLocalizedString("Unable to get chapter content, check the server", comment: ""))
            default:
                self?.warningView.show(text: NSLocalizedString("Error fetching chapter: Try again later", comment: ""))
            }
        }
    }

    private func display(html: String, url: URL) {
        self.progressBar.isHidden = false
        self.progressBar.progress = 0
        self.webView.loadHTMLString(self.htmlWrapper.wrap(html: html), baseURL: url)
    }
}

extension ChapterViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.progressBar.isHidden = true
    }
}
