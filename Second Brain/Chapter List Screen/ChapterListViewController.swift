import SBKit
import UIKit
import Result
import CBGPromise
import CoreSpotlight

class ChapterListViewController: UIViewController {
    private let bookService: BookService
    private let notificationCenter: NotificationCenter
    private let chapterViewControllerFactory: (Chapter) -> ChapterViewController
    private var bookFuture: Future<Result<Book, ServiceError>>!

    let tableDelesource = TreeTableDeleSource<Chapter>()

    @IBOutlet weak var warningView: WarningView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bookLoadProgress: UIProgressView!

    private let refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .white
        return control
    }()

    init(bookService: BookService, notificationCenter: NotificationCenter, chapterViewControllerFactory: @escaping (Chapter) -> ChapterViewController) {
        self.bookService = bookService
        self.chapterViewControllerFactory = chapterViewControllerFactory
        self.notificationCenter = notificationCenter

        super.init(nibName: "ChapterListViewController", bundle: Bundle(for: ChapterListViewController.self))

        self.requestChapters()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.refreshControl = self.refreshControl

        self.notificationCenter.addObserver(
            self,
            selector: #selector(ChapterListViewController.bookNotification(notification:)),
            name: BookServiceNotification.didFetchBook,
            object: nil
        )
        self.notificationCenter.addObserver(
            self,
            selector: #selector(ChapterListViewController.chapterNotification(notification:)),
            name: BookServiceNotification.didFetchChapterContent,
            object: nil
        )

        if self.bookFuture.value == nil {
            self.refreshControl.beginRefreshing()
        }
        self.tableDelesource.register(tableView: self.tableView) { chapter in
            self.show(chapter: chapter)
        }

        self.refreshControl.addTarget(self, action: #selector(ChapterListViewController.requestChapters), for: .valueChanged)

        self.tableView.tableFooterView = UIView()
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    override var keyCommands: [UIKeyCommand]? {
        let refresh = UIKeyCommand(
            __title: "Refresh Repository",
            action: #selector(ChapterListViewController.refreshBook),
            input: "r",
            modifierFlags: .command,
            propertyList: nil,
            alternates: []
        )
        return [refresh]
    }

    func resume(chapterActivity activity: NSUserActivity) -> Bool {
        guard activity.activityType == ChapterActivityType,
            let urlString = activity.userInfo?["urlString"] as? String,
            let url = URL(string: urlString) else { return false }

        return self.resume(url: url)
    }

    func resume(searchActivity activity: NSUserActivity) -> Bool {
        guard activity.activityType == CSSearchableItemActionType,
            let urlString = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let url = URL(string: urlString) else { return false }
        return self.resume(url: url)
    }

    @objc
    private func bookNotification(notification: Notification) {
        guard let bookNote = BookServiceNotification(notification: notification) else { return }
        self.bookLoadProgress.progress = 0
        self.bookLoadProgress.isHidden = false

        let progress = Float(bookNote.completedParts) / Float(bookNote.totalParts)

        self.bookLoadProgress.setProgress(progress, animated: true)
    }

    @objc
    private func chapterNotification(notification: Notification) {
        guard let chapterNote = BookServiceNotification(notification: notification) else { return }

        let progress = max(self.bookLoadProgress.progress, Float(chapterNote.completedParts) / Float(chapterNote.totalParts))

        self.bookLoadProgress.setProgress(progress, animated: true)
        if chapterNote.isFinished {
            self.bookLoadProgress.isHidden = true
        }
    }

    private func resume(url: URL) -> Bool {
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
    private func refreshBook() {
        guard self.bookFuture.value != nil else { return }
        self.refreshControl.beginRefreshing()
        self.requestChapters()
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
