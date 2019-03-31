import UIKit

class TreeTableCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var expandButton: UIButton!
    @IBOutlet weak var identConstraint: NSLayoutConstraint!

    private var expandCallback: ((TreeTableCell, Bool) -> Void)?

    private var isExpanded = false

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    @objc @IBAction
    func didTapExpandButton() {
        self.expandCallback?(self, !self.isExpanded)

        self.set(expanded: !self.isExpanded, animated: true)
    }

    func configure(title: String, childrenCount: Int, isExpanded: Bool, indentLevel: Int,
                   expandCallback: @escaping (TreeTableCell, Bool) -> Void) {
        self.titleLabel.text = title
        self.expandButton.isHidden = childrenCount == 0

        self.identConstraint.constant = CGFloat(8 * indentLevel)

        self.expandCallback = expandCallback
        self.set(expanded: isExpanded, animated: false)
    }

    private func set(expanded: Bool, animated: Bool) {
        let transform: CATransform3D
        if expanded {
            transform = CATransform3DMakeRotation(.pi, 1, 0, 0)
        } else {
            transform = CATransform3DIdentity
        }

        let shouldAnimate = !isTest() && animated

        CATransaction.begin()
        CATransaction.setDisableActions(!shouldAnimate)
        CATransaction.setAnimationDuration(shouldAnimate ? 0.25 : 0)
        CATransaction.setCompletionBlock {
            self.isExpanded = expanded
        }
        self.expandButton.layer.transform = transform
        CATransaction.commit()
    }
}
