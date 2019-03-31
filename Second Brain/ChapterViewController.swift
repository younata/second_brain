import SBKit
import UIKit

class ChapterViewController: UIViewController {
    private let bookService: BookService
    @IBOutlet weak var warningView: WarningView!

    let tableDelesource = TreeTableDeleSource<Chapter>()

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

    init(bookService: BookService) {
        self.bookService = bookService
        super.init(nibName: "ChapterViewController", bundle: Bundle(for: ChapterViewController.self))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refreshControl.beginRefreshing()
        self.requestChapters()
        self.tableDelesource.register(tableView: self.tableView)
        self.refreshControl.addTarget(self, action: #selector(ChapterViewController.requestChapters), for: .valueChanged)

        self.tableView.tableFooterView = UIView()
    }

    @objc
    private func requestChapters() {
        self.bookService.chapters().then { result in
            self.refreshControl.endRefreshing()

            switch result {
            case .success(let chapters):
                self.tableDelesource.update(items: chapters)
            case .failure(ServiceError.network(.http)):
                self.warningView.show(text: NSLocalizedString("Unable to get chapters, check the server", comment: ""))
            default:
                self.warningView.show(text: NSLocalizedString("Error getting chapters: Try again later", comment: ""))
            }
        }
    }
}

extension Chapter: Tree {
    public var description: String {
        return self.title
    }

    var children: [Chapter] { return self.subchapters }
}
