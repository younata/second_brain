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

    fileprivate var currentChapter: Chapter?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func didSelect(chapter: Chapter) {
        self.currentChapter = chapter
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
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            self.shouldAllowLink(to: url) { policy in
                decisionHandler(policy)
                if policy == .cancel {
                    self.urlOpener?.open(url)
                }
            }
        default:
            decisionHandler(.allow)
        }
    }

    private func shouldAllowLink(to url: URL, callback: @escaping (WKNavigationActionPolicy) -> Void) {
        if let chapterURL = self.currentChapter?.contentURL, self.baseURL(from: url) == chapterURL {
            callback(.allow)
            return
        }
        callback(.cancel)
    }

    private func baseURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }
}
