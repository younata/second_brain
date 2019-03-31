import CBGPromise
import Foundation

struct OperationQueueJumper {
    let queue: OperationQueue

    func jump<T>(_ future: Future<T>) -> Future<T> {
        let promise = Promise<T>()
        future.then { value in
            self.queue.addOperation {
                promise.resolve(value)
            }
        }
        return promise.future
    }

    func jump<T>(_ value: T) -> Future<T> {
        let promise = Promise<T>()
        self.queue.addOperation {
            promise.resolve(value)
        }
        return promise.future
    }
}
