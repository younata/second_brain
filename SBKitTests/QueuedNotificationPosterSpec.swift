import Quick
import Nimble
import Foundation
import Foundation_PivotalSpecHelper
@testable import SBKit

final class QueuedNotificationPosterSpec: QuickSpec {
    override func spec() {
        var subject: QueuedNotificationPoster!

        var queue: PSHKFakeOperationQueue!
        var center: NotificationCenter!

        var receivedNotifications: [Notification] = []

        beforeEach {
            receivedNotifications = []
            center = NotificationCenter()

            center!.addObserver(forName: BookServiceNotification.didFetchBook, object: nil, queue: nil) { notification in
                receivedNotifications.append(notification)
            }

            queue = PSHKFakeOperationQueue()

            subject = QueuedNotificationPoster(queue: queue, center: center)
        }

        describe("post(notification:)") {
            let notification = Notification(
                name: BookServiceNotification.didFetchBook,
                object: nil,
                userInfo: ["some": "thing"]
            )

            beforeEach {
                subject.post(notification: notification)
            }

            it("adds an operation to the queue") {
                expect(queue.operationCount).to(equal(1))
            }

            it("does not yet send the notification") {
                expect(receivedNotifications).to(beEmpty())
            }

            describe("when the operation runs") {
                beforeEach {
                    queue.runNextOperation()
                }

                it("does not enqueue any other operations") {
                    expect(queue.operationCount).to(equal(0))
                }

                it("sends the notification") {
                    expect(receivedNotifications).to(equal([notification]))
                }
            }
        }
    }
}
