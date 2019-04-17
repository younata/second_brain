import Kanna
import CoreServices
import CoreSpotlight

public protocol ActivityService {
    func activity(for: Chapter) -> NSUserActivity
}

protocol SearchIndex {
    func deleteSearchableItems(withIdentifiers identifiers: [String], completionHandler: ((Error?) -> Void)?)
    func indexSearchableItems(_ items: [CSSearchableItem], completionHandler: ((Error?) -> Void)?)

    func beginBatch()
    func endBatch(withClientState clientState: Data, completionHandler: ((Error?) -> Void)?)
}

extension CSSearchableIndex: SearchIndex {}

protocol SearchIndexService {
    func update(chapter: Chapter, content: String)
    func endRefresh()
}

public let ChapterActivityType = "com.rachelbrindle.second_brain.read_chapter"

final class SearchActivityService: ActivityService, SearchIndexService, BookServiceDelegate {
    private var activities: [Chapter: NSUserActivity] = [:]
    private let searchIndex: SearchIndex
    private let searchQueue: OperationQueue

    init(searchIndex: SearchIndex, searchQueue: OperationQueue) {
        self.searchIndex = searchIndex
        self.searchQueue = searchQueue
    }

    // MARK: ActivityService
    func activity(for chapter: Chapter) -> NSUserActivity {
        if let activity = self.activities[chapter] { return activity }
        let activity = NSUserActivity(activityType: ChapterActivityType)
        self.update(activity: activity, from: chapter, content: nil)
        self.activities[chapter] = activity
        return activity
    }

    // MARK: SearchIndexService
    private var updatedChapters: [Chapter: String] = [:]
    private var removedChapters: [String] = []

    func startRefresh() {
        self.searchQueue.addOperation {
            self.searchIndex.beginBatch()
        }
    }

    func update(chapter: Chapter, content: String) {
        self.searchQueue.addOperation {
            if let activity = self.activities[chapter] {
                activity.contentAttributeSet = self.attributes(for: chapter, content: content)
                activity.needsSave = true
            }
            self.updatedChapters[chapter] = content
        }
    }

    func endRefresh() {
        self.searchQueue.addOperation {
            guard !self.updatedChapters.isEmpty || !self.removedChapters.isEmpty else {
                return
            }
            self.searchIndex.beginBatch()
            let items = self.updatedChapters.map { (chapter, content) in
                return self.item(for: chapter, content: content)
            }
            self.searchIndex.indexSearchableItems(items, completionHandler: nil)
            self.searchIndex.deleteSearchableItems(withIdentifiers: self.removedChapters, completionHandler: nil)
            self.searchIndex.endBatch(withClientState: Data(), completionHandler: nil)
            self.updatedChapters = [:]
            self.removedChapters = []
        }
    }

    // MARK: BookServiceDelegate
    func didRemove(chapter: Chapter) {
        self.searchQueue.addOperation {
            if let activity = self.activities[chapter] {
                activity.invalidate()
                self.activities.removeValue(forKey: chapter)
            }
            self.removedChapters.append(chapter.contentURL.absoluteString)
        }
    }

    private func update(activity: NSUserActivity, from chapter: Chapter, content: String?) {
        activity.webpageURL = chapter.contentURL
        activity.keywords = [chapter.title]
        activity.userInfo = ["urlString": chapter.contentURL.absoluteString]
        activity.requiredUserInfoKeys = ["urlString"]
        activity.contentAttributeSet = self.attributes(for: chapter, content: content)
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = false
        activity.isEligibleForPublicIndexing = false
        activity.needsSave = true
    }

    private func attributes(for chapter: Chapter, content: String?) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
        attributes.title = chapter.title
        attributes.url = chapter.contentURL
        attributes.displayName = chapter.title
        attributes.subject = chapter.title
        attributes.htmlContentData = content?.data(using: .utf8)

        if let document = content, let (description, headers) = self.parse(document: document) {
            attributes.contentDescription = description
            attributes.keywords = [chapter.title] + headers
        }

        return attributes
    }

    private func item(for chapter: Chapter, content: String) -> CSSearchableItem {
        return CSSearchableItem(
            uniqueIdentifier: chapter.contentURL.absoluteString,
            domainIdentifier: "com.rachelbrindle.second_brain.chapter",
            attributeSet: self.attributes(for: chapter, content: content)
        )
    }

    private func parse(document: String) -> (String, [String])? {
        guard let doc = try? HTML(html: document, encoding: .utf8) else {
            return nil
        }

        let firstParagraph = doc.css("p").first?.text ?? ""
        let headers = doc.css("h2,h3,h4,h5,h6").compactMap { $0.text }

        return (firstParagraph, headers)
    }
}
