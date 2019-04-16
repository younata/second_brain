import CoreServices
import CoreSpotlight

public protocol ActivityService {
    func activity(for: Chapter) -> NSUserActivity
}

protocol SearchIndex {
    func deleteAllSearchableItems(completionHandler: ((Error?) -> Void)?)
    func indexSearchableItems(_ items: [CSSearchableItem], completionHandler: ((Error?) -> Void)?)

    func beginBatch()
    func endBatch(withClientState clientState: Data, completionHandler: ((Error?) -> Void)?)
}

extension CSSearchableIndex: SearchIndex {}

protocol SearchIndexService {
    func startRefresh()
    func update(chapter: Chapter, content: String)
    func endRefresh()
}

public let ChapterActivityType = "com.rachelbrindle.second_brain.read_chapter"

final class SearchActivityService: ActivityService, SearchIndexService {
    private var activities: [Chapter: NSUserActivity] = [:]

    // MARK: ActivityService
    func activity(for chapter: Chapter) -> NSUserActivity {
        if let activity = self.activities[chapter] { return activity }
        let activity = NSUserActivity(activityType: ChapterActivityType)
        self.update(activity: activity, from: chapter, content: nil)
        self.activities[chapter] = activity
        return activity
    }

    // MARK: SearchIndexService
    func startRefresh() {}
    func update(chapter: Chapter, content: String) {}
    func endRefresh() {}

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
        attributes.htmlContentData = content?.data(using: .utf8)
        return attributes
    }
}
