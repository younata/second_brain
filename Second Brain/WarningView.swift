import UIKit

@IBDesignable
class WarningView: UIView {
    let imageView: UIImageView
    let label: UILabel

    enum Style {
        case warning
        case error
    }

    override init(frame: CGRect) {
        self.imageView = UIImageView()
        self.label = UILabel()

        super.init(frame: frame)

        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        self.imageView = UIImageView()
        self.label = UILabel()

        super.init(coder: aDecoder)

        self.commonInit()
    }

    private func commonInit() {
        self.addSubview(self.imageView)
        self.addSubview(self.label)

        self.backgroundColor = UIColor.yellow

        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.label.translatesAutoresizingMaskIntoConstraints = false

        let margins = self.layoutMarginsGuide
        let inset: CGFloat = 8

        self.imageView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: inset).isActive = true
        self.imageView.centerYAnchor.constraint(equalTo: self.label.centerYAnchor).isActive = true

        self.label.leadingAnchor.constraint(equalTo: self.imageView.trailingAnchor, constant: inset).isActive = true
        self.label.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: inset).isActive = true
        self.label.topAnchor.constraint(equalTo: margins.topAnchor, constant: inset).isActive = true
        self.label.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: inset).isActive = true

        self.transform = CGAffineTransform(scaleX: 1, y: 0)
    }

    func show(text: String) {
        self.label.text = text

        let animator = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 0.8) {
            self.transform = CGAffineTransform.identity
        }
        animator.addCompletion { position in
            let closeAnimator = UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
                self.transform = CGAffineTransform(scaleX: 1, y: 0)
            }
            closeAnimator.startAnimation(afterDelay: 4)
        }
        animator.startAnimation()
    }
}
