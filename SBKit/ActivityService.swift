import CoreServices
import CoreSpotlight

public protocol ActivityService {
    func activity(for: Chapter) -> NSUserActivity
}

public let ChapterActivityType = "com.rachelbrindle.second_brain.read_chapter"

final class SearchActivityService: ActivityService {
    private var activities: [Chapter: NSUserActivity] = [:]

    func activity(for chapter: Chapter) -> NSUserActivity {
        if let activity = self.activities[chapter] { return activity }
        let activity = NSUserActivity(activityType: ChapterActivityType)
        activity.webpageURL = chapter.contentURL
        activity.keywords = [chapter.title]
        activity.userInfo = ["urlString": chapter.contentURL.absoluteString]
        activity.requiredUserInfoKeys = ["urlString"]
        activity.contentAttributeSet = self.attributes(for: chapter, content: nil)
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = false
        activity.isEligibleForPublicIndexing = false
        self.activities[chapter] = activity
        return activity
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
