import CoreSpotlight
import CoreServices

public protocol ActivityService {
    func activity(for: Chapter) -> NSUserActivity
}

let ChapterActivityType = "com.rachelbrindle.second_brain.activity.chapter"

struct SearchActivityService: ActivityService {
    func activity(for chapter: Chapter) -> NSUserActivity {
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
