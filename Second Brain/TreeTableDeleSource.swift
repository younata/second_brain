import UIKit

protocol Tree: CustomStringConvertible, Equatable {
    var children: [Self] { get }
}

extension Tree {
    func hasSubchild(_ potentialChild: Self) -> Bool {
        return self.expandedChildren().contains(potentialChild)
    }

    private func expandedChildren() -> [Self] {
        return self.children.flatMap { [$0] + $0.expandedChildren() }
    }

    func depth(child: Self) -> Int? {
        guard self != child else { return 0 }
        guard !self.children.isEmpty else { return nil }
        guard !self.children.contains(child) else { return 1 }

        guard let depth = self.children.compactMap({ $0.depth(child: child) }).first else {
            return nil
        }

        return depth + 1
    }
}

final class TreeTableDeleSource<Item: Tree>: NSObject, UITableViewDataSource, UITableViewDelegate {
    private(set) var items: [Item] = [] {
        didSet {
            self.shownItems = self.items
        }
    }

    private var shownItems: [Item] = []

    private(set) var tableView: UITableView!

    private let cellName = "treeCell"

    func update(items: [Item]) {
        self.items = items
        self.tableView.reloadData()
    }

    func register(tableView: UITableView) {
        self.tableView = tableView

        tableView.register(
            UINib(nibName: "TreeTableCell", bundle: Bundle(for: TreeTableCell.self)),
            forCellReuseIdentifier: self.cellName
        )
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func item(at indexPath: IndexPath) -> Item {
        return self.shownItems[indexPath.row]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.shownItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellName, for: indexPath) as? TreeTableCell else {
            // log the error
            return UITableViewCell()
        }
        let item = self.item(at: indexPath)

        cell.configure(
            title: item.description,
            childrenCount: item.children.count,
            isExpanded: self.isItemExpanded(indexPath: indexPath),
            indentLevel: self.indentation(of: item),
            expandCallback: self.expandButtonTapped
        )

        return cell
    }

    private func indentation(of item: Item) -> Int {
        return self.items.compactMap { $0.depth(child: item) }.first ?? 0
    }

    private func isItemExpanded(indexPath: IndexPath) -> Bool {
        let item = self.item(at: indexPath)

        if item.children.isEmpty || indexPath.row + 1 == self.shownItems.count {
            return false
        } else {
            return self.shownItems[indexPath.row + 1] == item.children[0]
        }
    }

    private func expandButtonTapped(for cell: TreeTableCell, willExpand: Bool) {
        guard let indexPath = self.tableView.indexPath(for: cell) else { return }

        if willExpand {
            self.insertChildren(indexPath: indexPath, item: self.item(at: indexPath))
        } else {
            self.removeChildren(indexPath: indexPath, item: self.item(at: indexPath))
        }
    }

    private func insertChildren(indexPath: IndexPath, item: Item) {
        let children = item.children

        let indexPaths = (0..<children.count).map { index in
            return IndexPath(row: indexPath.row + 1 + index, section: 0)
        }

        self.shownItems.insert(contentsOf: children, at: indexPath.row + 1)

        self.tableView.insertRows(at: indexPaths, with: .none) // will be a custom animation... later
    }

    private func removeChildren(indexPath: IndexPath, item: Item) {
        let toRemove = self.shownItems.filter { item.hasSubchild($0) }
        let indices = toRemove.compactMap { self.shownItems.index(of: $0) }
        let indexPaths = indices.map { IndexPath(row: $0, section: 0) }

        for index in indices.sorted().reversed() {
            self.shownItems.remove(at: index)
        }

        self.tableView.deleteRows(at: indexPaths, with: .none)
    }
}
