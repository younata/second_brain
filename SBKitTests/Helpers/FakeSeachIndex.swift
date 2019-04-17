import Nimble
import CoreSpotlight
@testable import SBKit

final class FakeSearchIndex: SearchIndex {
    private(set) var deleteSearchableItemsCalls: [(identifier: [String], handler: ((Error?) -> Void)?)] = []
    func deleteSearchableItems(withIdentifiers identifiers: [String], completionHandler: ((Error?) -> Void)?) {
        expect(self.isUpdating).to(beTruthy())
        self.deleteSearchableItemsCalls.append((identifiers, completionHandler))
    }
    private(set) var indexSearchableItemsCalls: [(items: [CSSearchableItem], completionHandler: ((Error?) -> Void)?)] = []
    func indexSearchableItems(_ items: [CSSearchableItem], completionHandler: ((Error?) -> Void)?) {
        expect(self.isUpdating).to(beTruthy())
        self.indexSearchableItemsCalls.append((items, completionHandler))
    }

    private(set) var isUpdating: Bool = false
    func beginBatch() {
        expect(self.isUpdating).to(beFalsy())

        self.isUpdating = true
    }

    func endBatch(withClientState clientState: Data, completionHandler: ((Error?) -> Void)?) {
        expect(self.isUpdating).to(beTruthy())

        self.isUpdating = false
    }
}
