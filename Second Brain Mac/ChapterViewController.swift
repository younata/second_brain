import Cocoa
import SBKit
import WebKit

class ChapterViewController: NSViewController, ChapterSelectionSubscriber {
    @IBOutlet weak var webView: WKWebView!

    var bookService: BookService?
    var htmlWrapper: HTMLWrapper?
    var activityService: ActivityService?
    var chapterSelectionPublisher: ChapterSelectorPubSub? {
        didSet {
            chapterSelectionPublisher?.add(subscriber: self)
        }
    }
    var urlOpener: URLOpener?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func didSelect(chapter: Chapter) {
        self.userActivity = self.activityService?.activity(for: chapter)
        self.bookService?.content(of: chapter).then { [weak self] result in
            switch result {
            case .success(let content):
                guard let wrappedContent = self?.htmlWrapper?.wrap(html: content) else { return }
                self?.webView?.loadHTMLString(wrappedContent, baseURL: chapter.contentURL)
            case .failure(let error):
                self?.show(error: error)
            }
        }
    }

    private func show(error: ServiceError) {
        let alert = NSAlert(error: error)
        alert.messageText = error.title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

extension ChapterViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationAction.navigationType {
        case .linkActivated:
            decisionHandler(.cancel)
            guard let url = navigationAction.request.url else { return }
            self.urlOpener?.open(url)
        default:
            decisionHandler(.allow)
        }
    }
}
