import Foundation

protocol NotificationPoster {
    func post(notification: Notification)
}

struct QueuedNotificationPoster: NotificationPoster {
    private let queue: OperationQueue
    private let center: NotificationCenter

    init(queue: OperationQueue, center: NotificationCenter) {
        self.queue = queue
        self.center = center
    }

    func post(notification: Notification) {
        self.queue.addOperation {
            self.center.post(notification)
        }
    }
}
