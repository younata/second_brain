import SBKit
import UIKit
import Result
import CBGPromise

class ChapterListViewController: UIViewController {
    private let bookService: BookService
    private let chapterViewControllerFactory: (Chapter) -> ChapterViewController
    private var bookFuture: Future<Result<Book, ServiceError>>!

    let tableDelesource = TreeTableDeleSource<Chapter>()

    @IBOutlet weak var warningView: WarningView!
    @IBOutlet var tableViewController: UITableViewController!
    @IBOutlet weak var tableView: UITableView!

    private var refreshControl: UIRefreshControl {
        guard let refreshControl = self.tableViewController.refreshControl else {
            let refreshControl = UIRefreshControl()
            self.tableViewController.refreshControl = refreshControl
            return refreshControl
        }
        return refreshControl
    }

    init(bookService: BookService, chapterViewControllerFactory: @escaping (Chapter) -> ChapterViewController) {
        self.bookService = bookService
        self.chapterViewControllerFactory = chapterViewControllerFactory

        super.init(nibName: "ChapterListViewController", bundle: Bundle(for: ChapterListViewController.self))

        self.requestChapters()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if self.bookFuture.value == nil {
            self.refreshControl.beginRefreshing()
        }
        self.tableDelesource.register(tableView: self.tableView) { chapter in
            self.show(chapter: chapter)
        }

        self.refreshControl.addTarget(self, action: #selector(ChapterListViewController.requestChapters), for: .valueChanged)

        self.tableView.tableFooterView = UIView()
    }

    func resume(chapterActivity activity: NSUserActivity) -> Bool {
        guard activity.activityType == ChapterActivityType,
            let urlString = activity.userInfo?["urlString"] as? String,
            let url = URL(string: urlString) else { return false }

        guard let bookResult = self.bookFuture.value else {
            self.bookFuture.then { [weak self] (bookResult: Result<Book, ServiceError>) in
                self?.presentChapter(with: url, and: bookResult, showError: true)
            }
            return true
        }
        return self.presentChapter(with: url, and: bookResult, showError: false)
    }

    @discardableResult
    private func presentChapter(with url: URL, and result: Result<Book, ServiceError>, showError: Bool) -> Bool {

        let errorString: String

        switch result {
        case .success(let book):
            if let chapter = book.flatChapters.first(where: { $0.contentURL == url }) {
                self.show(chapter: chapter)
                return true
            }
            errorString = NSLocalizedString("Unable to open chapter: Not found", comment: "")
        case .failure:
            errorString = NSLocalizedString("Unable to open chapter: Unable to get chapters", comment: "")
        }

        if showError {
            self.warningView.show(text: errorString)
        }
        return false
    }

    @objc
    private func requestChapters() {
        self.bookFuture = self.bookService.book().then { [weak self] result in
            _ = self?.view // force the view to load if it hasn't already.
            self?.refreshControl.endRefreshing()

            switch result {
            case .success(let book):
                self?.title = book.title
                self?.tableDelesource.update(items: book.chapters)
            case .failure(ServiceError.network(.http)):
                self?.warningView.show(text: NSLocalizedString("Unable to get chapters, check the server", comment: ""))
            default:
                self?.warningView.show(text: NSLocalizedString("Error getting chapters: Try again later", comment: ""))
            }
        }
    }

    private func show(chapter: Chapter) {
        let navController = UINavigationController(rootViewController: self.chapterViewControllerFactory(chapter))
        navController.hidesBarsOnSwipe = true
        navController.hidesBarsOnTap = true
        self.showDetailViewController(navController, sender: nil)
    }
}

extension Chapter: Tree {
    public var description: String {
        return self.title
    }

    var children: [Chapter] { return self.subchapters }
}
