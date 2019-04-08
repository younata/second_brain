import SBKit
import UIKit

class ChapterListViewController: UIViewController {
    private let bookService: BookService
    private let chapterViewControllerFactory: (Chapter) -> ChapterViewController

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
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refreshControl.beginRefreshing()
        self.requestChapters()
        self.tableDelesource.register(tableView: self.tableView) { chapter in
            self.show(chapter: chapter)
        }

        self.refreshControl.addTarget(self, action: #selector(ChapterListViewController.requestChapters), for: .valueChanged)

        self.tableView.tableFooterView = UIView()
    }

    @objc
    private func requestChapters() {
        self.bookService.book().then { result in
            self.refreshControl.endRefreshing()

            switch result {
            case .success(let book):
                self.title = book.title
                self.tableDelesource.update(items: book.chapters)
            case .failure(ServiceError.network(.http)):
                self.warningView.show(text: NSLocalizedString("Unable to get chapters, check the server", comment: ""))
            default:
                self.warningView.show(text: NSLocalizedString("Error getting chapters: Try again later", comment: ""))
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
