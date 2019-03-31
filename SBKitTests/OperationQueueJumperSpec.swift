import Quick
import Nimble
import CBGPromise
import Foundation
import Foundation_PivotalSpecHelper
@testable import SBKit

final class OperationQueueJumperSpec: QuickSpec {
    override func spec() {
        var subject: OperationQueueJumper!

        var queue: PSHKFakeOperationQueue!

        beforeEach {
            queue = PSHKFakeOperationQueue()

            subject = OperationQueueJumper(queue: queue)
        }

        describe("jump(:) with a future") {
            var promise: Promise<Int>!
            var future: Future<Int>!

            beforeEach {
                promise = Promise<Int>()

                future = subject.jump(promise.future)
            }

            it("returns an in-progress future") {
                expect(future.value).to(beNil())
            }

            describe("when the promise resolves") {
                beforeEach {
                    promise.resolve(5)
                }

                it("does not yet resolve the future") {
                    expect(future.value).to(beNil())
                }

                it("adds an operation to the operation queue") {
                    expect(queue.operationCount).to(equal(1))
                }

                describe("when the operation runs") {
                    beforeEach {
                        queue.runNextOperation()
                    }

                    it("resolves the future") {
                        expect(future.value).to(equal(5))
                    }

                    it("does not touch the operation queue again") {
                        expect(queue.operationCount).to(equal(0))
                    }
                }
            }
        }

        describe("jump(:) with a non-future") {
            var future: Future<Int>!

            beforeEach {
                future = subject.jump(5)
            }

            it("returns an in-progress future") {
                expect(future.value).to(beNil())
            }

            it("adds an operation to the operation queue") {
                expect(queue.operationCount).to(equal(1))
            }

            describe("when the operation runs") {
                beforeEach {
                    queue.runNextOperation()
                }

                it("resolves the future") {
                    expect(future.value).to(equal(5))
                }

                it("does not touch the operation queue again") {
                    expect(queue.operationCount).to(equal(0))
                }
            }
        }
    }
}
