import Quick
import Nimble

final class NSUserActivitySpecHelperSpec: QuickSpec {
    override func spec() {
        var subject: NSUserActivity!

        beforeEach {
            subject = NSUserActivity(activityType: "myActivity")
        }

        afterEach {
            subject.invalidate()
        }

        it("is valid") {
            expect(subject.isValid).to(beTruthy())
        }

        it("is not active") {
            expect(subject.isActive).to(beFalsy())
        }

        describe("activating it") {
            beforeEach {
                subject.becomeCurrent()
            }

            it("is valid") {
                expect(subject.isValid).to(beTruthy())
            }

            it("is active") {
                expect(subject.isActive).to(beTruthy())
            }

            describe("deactivating it") {
                beforeEach {
                    subject.resignCurrent()
                }

                it("is valid") {
                    expect(subject.isValid).to(beTruthy())
                }

                it("is not active") {
                    expect(subject.isActive).to(beFalsy())
                }
            }

            describe("invalidating it") {
                beforeEach {
                    subject.invalidate()
                }

                it("is not valid") {
                    expect(subject.isValid).to(beFalsy())
                }

                it("is not active") {
                    expect(subject.isActive).to(beFalsy())
                }
            }
        }

        describe("invalidating it") {
            beforeEach {
                subject.invalidate()
            }

            it("is not valid") {
                expect(subject.isValid).to(beFalsy())
            }

            it("is not active") {
                expect(subject.isActive).to(beFalsy())
            }
        }
    }
}
