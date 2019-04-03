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

    private var forwardExpandCalls = true
    @objc @IBAction
    func didTapExpandButton() {
        guard self.forwardExpandCalls else { return }
        self.forwardExpandCalls = false
        self.expandCallback?(self, !self.isExpanded)

        self.set(expanded: !self.isExpanded, animated: true) {
            self.forwardExpandCalls = true
        }
    }

    func configure(title: String, childrenCount: Int, isExpanded: Bool, indentLevel: Int,
                   expandCallback: @escaping (TreeTableCell, Bool) -> Void) {
        self.titleLabel.text = title
        self.expandButton.isHidden = childrenCount == 0

        self.identConstraint.constant = CGFloat(16 * indentLevel)

        self.expandCallback = expandCallback
        self.set(expanded: isExpanded, animated: false) {}
    }

    private func set(expanded: Bool, animated: Bool, finishCallback: @escaping () -> Void) {
        guard self.isExpanded != expanded else { return }
        let rotation: CGFloat
        if expanded {
            rotation = .pi
        } else {
            rotation = 0
        }
        let transform = CATransform3DMakeRotation(rotation, 1, 0, 0)
        let shouldAnimate = !isTest() && animated
        let animationDuration: TimeInterval = shouldAnimate ? 0.25 : 0

        let completionHandler: (Bool) -> Void = { _ in
            self.expandButton.layer.transform = transform
            self.isExpanded = expanded
            finishCallback()
        }

        if shouldAnimate {
            let animation = CABasicAnimation(keyPath: "transform.rotation.x")
            animation.toValue = rotation
            animation.duration = animationDuration
            let animationDelegate = BlockAnimationDelegate()
            animationDelegate.onComplete = completionHandler
            animation.delegate = animationDelegate
            self.expandButton.layer.add(animation, forKey: "rotation")
        } else {
            completionHandler(true)
        }
    }
}

class BlockAnimationDelegate: NSObject, CAAnimationDelegate {
    var onComplete: ((Bool) -> Void)? = nil
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        self.onComplete?(flag)
    }
}
