import UIKit
import UIKit_PivotalSpecHelperStubs

import Quick
import Nimble

@testable import Second_Brain

final class WarningViewSpec: QuickSpec {
    override func spec() {
        var subject: WarningView!

        beforeEach {
            subject = WarningView(frame: CGRect(x: 0, y: 0, width: 120, height: 40))
        }

        it("configures the view") {
            expect(subject.backgroundColor).to(equal(UIColor.yellow))
            expect(subject.transform).to(equal(CGAffineTransform(scaleX: 1, y: 0)))
        }

        describe("show(text:)") {
            beforeEach {
                subject.show(text: "Some Text")
            }

            it("sets the text on the label") {
                expect(subject.label.text).to(equal("Some Text"))
            }
        }
    }
}
