import UIKit
import Quick
import Nimble

final class UIViewControllerSpecHelperSpec: QuickSpec {
    override func spec() {
        var subject: UIViewController!

        beforeEach {
            subject = UIViewController()

            subject.view.layoutIfNeeded()
        }

        describe("detailViewController") {
            var otherController: UIViewController!
            beforeEach {
                otherController = UIViewController()
                subject.showDetailViewController(otherController, sender: nil)
            }

            it("records the that detail view controller was shown") {
                expect(subject.detail).to(beIdenticalTo(otherController))
            }
        }

        describe("shownViewController") {
            var otherController: UIViewController!
            beforeEach {
                otherController = UIViewController()
                subject.show(otherController, sender: nil)
            }

            it("records the that detail view controller was shown") {
                expect(subject.shown).to(beIdenticalTo(otherController))
            }
        }
    }
}
