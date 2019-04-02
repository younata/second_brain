import Quick
import Nimble
import UIKit

@testable import Second_Brain

final class TreeTableDeleSourceSpec: QuickSpec {
    override func spec() {
        var subject: TreeTableDeleSource<TreeItem>!

        var tableView: UITableView!

        let items: [TreeItem] = [
            TreeItem(title: "Item 1", children: [
                TreeItem(title: "Item 1.1", children: []),
                TreeItem(title: "Item 1.2", children: []),
                TreeItem(title: "Item 1.3", children: [])
            ]),
            TreeItem(title: "Item 2", children: [
                TreeItem(title: "Item 2.1", children: []),
                TreeItem(title: "Item 2.2", children: [
                    TreeItem(title: "Item 2.2.1", children: []),
                ]),
                TreeItem(title: "Item 2.3", children: []),
                TreeItem(title: "Item 2.4", children: [])
            ]),
            TreeItem(title: "Item 3", children: [
                TreeItem(title: "Item 3.1", children: []),
                TreeItem(title: "Item 3.2", children: [])
            ]),
            TreeItem(title: "Item 4", children: []),
            TreeItem(title: "Item 5", children: [
                TreeItem(title: "Item 5.1", children: [])
            ]),
        ]

        var callbacks: [TreeItem] = []

        beforeEach {
            callbacks = []
            tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 560))

            subject = TreeTableDeleSource()
            subject.register(tableView: tableView, onSelect: { item in callbacks.append(item) })
            subject.update(items: items)
        }

        it("shows only rows for the top-level items") {
            expect(tableView.numberOfSections).to(equal(1))
            expect(tableView.numberOfRows(inSection: 0)).to(equal(5))
        }

        func describeACell(row: Int, item: TreeItem, indentAmount: Int = 0) {
            describe("cell at row \(row)") {
                var cell: TreeTableCell?

                let indexPath = IndexPath(row: row, section: 0)
                beforeEach {
                    cell = tableView.cellForRow(at: indexPath) as? TreeTableCell

                    guard cell != nil else {
                        fail("Unable to get cell")
                        return
                    }
                }

                it("configure's the cell's title") {
                    expect(cell?.titleLabel.text).to(equal(item.title))
                }

                it("indents the cell if needed") {
                    let leadingEdgeOfTitleLabel = cell?.titleLabel.frame.minX ?? 0
                    let calculatedIndentLevel = Int((leadingEdgeOfTitleLabel - 8) / 16)
                    expect(calculatedIndentLevel).to(equal(indentAmount))
                }

                describe("tapping the cell") {
                    beforeEach {
                        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
                    }

                    it("calls the callback with the tapped item.") {
                        expect(callbacks).to(equal([item]))
                    }

                    it("deselects the row") {
                        expect(tableView.indexPathsForSelectedRows ?? []).to(beEmpty())
                    }
                }

                if item.children.isEmpty {
                    it("does not show the expand button") {
                        expect(cell?.expandButton.isHidden).to(beTruthy())
                    }
                } else {
                    it("shows the expand button") {
                        expect(cell?.expandButton.isHidden).to(beFalsy())
                    }

                    it("has the expand button pointed down") {
                        expect(cell?.expandButton.layer.transform).to(equal(CATransform3DIdentity))
                    }

                    describe("tapping the expand button") {
                        var originalRowCount: Int = 0
                        beforeEach {
                            originalRowCount = tableView.numberOfRows(inSection: 0)

                            cell?.expandButton.tap()
                        }

                        it("rotates the expandButton to indicate it's expanded") {
                            expect(cell?.expandButton.layer.transform).to(equal(CATransform3DMakeRotation(.pi, 1, 0, 0)))
                        }

                        it("inserts \(item.children.count) more rows in the tableview") {
                            expect(tableView.numberOfSections).to(equal(1))
                            expect(tableView.numberOfRows(inSection: 0) - originalRowCount).to(equal(item.children.count))
                        }

                        for (index, child) in item.children.enumerated() {
                            describeACell(row: row + index + 1, item: child, indentAmount: indentAmount + 1)
                        }

                        describe("tapping the expand button again") {
                            beforeEach {
                                RunLoop.main.run(until: Date(timeIntervalSinceNow: 1e-2)) // needs to spin the runloop for the completion block to be called.
                                cell?.expandButton.tap()
                            }

                            it("rotates the expand button again to indicate it's contracted") {
                                expect(cell?.expandButton.layer.transform).toEventually(equal(CATransform3DIdentity))
                            }

                            it("removes the children from the tableview") {
                                expect(tableView.numberOfSections).to(equal(1))
                                expect(tableView.numberOfRows(inSection: 0)).to(equal(originalRowCount))
                            }
                        }
                    }
                }
            }
        }

        for (row, item) in items.enumerated() {
            describeACell(row: row, item: item)
        }

        describe("unexpanding a row when multiple children are showing") {
            beforeEach {
                func cell(row: Int) -> TreeTableCell? {
                    let indexPath = IndexPath(row: row, section: 0)
                    let cell = tableView.cellForRow(at: indexPath) as? TreeTableCell

                    guard cell != nil else {
                        fail("Unable to get cell")
                        return nil
                    }
                    return cell
                }

                let item2Cell = cell(row: 1) // item 2.
                item2Cell?.tap()
                let item22Cell = cell(row: 3) // item 2.2, which has children.
                item22Cell?.tap()

                item2Cell?.tap()
            }

            it("removes the cell's children, and all subchildren of those cells (and so forth)") {
                expect(tableView.numberOfSections).to(equal(1))
                expect(tableView.numberOfRows(inSection: 0)).to(equal(5))
            }
        }
    }
}

extension CATransform3D: Equatable {
    public static func == (lhs: CATransform3D, rhs: CATransform3D) -> Bool {
        return lhs.m11 ≈ rhs.m11 && lhs.m12 ≈ rhs.m12 && lhs.m13 ≈ rhs.m13 && lhs.m14 ≈ rhs.m14 &&
            lhs.m21 ≈ rhs.m21 && lhs.m22 ≈ rhs.m22 && lhs.m23 ≈ rhs.m23 && lhs.m24 ≈ rhs.m24 &&
            lhs.m31 ≈ rhs.m31 && lhs.m32 ≈ rhs.m32 && lhs.m33 ≈ rhs.m33 && lhs.m34 ≈ rhs.m34 &&
            lhs.m41 ≈ rhs.m41 && lhs.m42 ≈ rhs.m42 && lhs.m43 ≈ rhs.m43 && lhs.m44 ≈ rhs.m44

    }
}

extension CGFloat {
    public static func ≈(lhs: CGFloat, rhs: CGFloat) -> Bool {
        return abs(lhs - rhs) < 1e-6
    }
}

private struct TreeItem: Tree {
    let title: String
    let children: [TreeItem]

    var description: String { return self.title }
}

final class TreeSpec: QuickSpec {
    override func spec() {
        let items: [TreeItem] = [
            TreeItem(title: "Item 1", children: [
                TreeItem(title: "Item 1.1", children: []),
                TreeItem(title: "Item 1.2", children: []),
                TreeItem(title: "Item 1.3", children: [])
            ]),
            TreeItem(title: "Item 2", children: [
                TreeItem(title: "Item 2.1", children: []),
                TreeItem(title: "Item 2.2", children: [
                    TreeItem(title: "Item 2.2.1", children: []),
                ]),
                TreeItem(title: "Item 2.3", children: []),
                TreeItem(title: "Item 2.4", children: [])
            ]),
            TreeItem(title: "Item 3", children: [
                TreeItem(title: "Item 3.1", children: []),
                TreeItem(title: "Item 3.2", children: [])
            ]),
            TreeItem(title: "Item 4", children: []),
            TreeItem(title: "Item 5", children: [
                TreeItem(title: "Item 5.1", children: [])
            ]),
        ]

        describe("-hasSubchild(:)") {
            it("returns true when the item is a direct child") {
                expect(items[0].hasSubchild(items[0].children[1])).to(beTruthy())
            }

            it("returns false when the items are unrelated") {
                expect(items[0].hasSubchild(items[4].children[0])).to(beFalsy())
            }

            it("returns true when the potential child is a grandchild") {
                expect(items[1].hasSubchild(items[1].children[1].children[0])).to(beTruthy())
            }
        }

        describe("-depth(child:)") {
            it("returns nil when the given child is not in the tree of self") {
                expect(items[0].depth(child: items[2])).to(beNil())
            }

            it("returns 0 when the given child IS self") {
                expect(items[0].depth(child: items[0])).to(equal(0))
            }

            it("returns 1 when the given child is an immediate subchild") {
                let parent = items[0]
                expect(parent.depth(child: parent.children[0])).to(equal(1))
            }

            it("returns 2 when the given child is aa grandchild of the received") {
                let parent = items[1]
                let grandchild = parent.children[1].children[0]
                expect(parent.depth(child: grandchild)).to(equal(2))
            }
        }
    }
}
