@testable import SBKit

final class FakeNotificationPoster: NotificationPoster {
    private(set) var notifications: [Notification] = []
    func post(notification: Notification) {
        self.notifications.append(notification)
    }

    func reset() {
        self.notifications = []
    }
}
