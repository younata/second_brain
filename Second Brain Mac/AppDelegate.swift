import Cocoa
import SBKit
import Swinject
import CoreSpotlight
import SwinjectStoryboard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private var storyboard: SwinjectStoryboard!
    private var windowController: NSWindowController?
    private lazy var injector: Container = {
        let container = Container()
        SBKit.register(container)
        Second_Brain.register(container)
        return container
    }()

    private var chapterTreeController: ChapterTreeViewController? {
        self.loadUIIfNeeded()
        guard let splitController = self.windowController?.contentViewController?.children.first as? NSSplitViewController else { return nil }
        return splitController.children.first as? ChapterTreeViewController
    }

    private func loadUIIfNeeded() {
        guard self.windowController == nil else { return }
        self.storyboard = SwinjectStoryboard.create(name: "UI", bundle: nil, container: self.injector)

        self.windowController = storyboard.instantiateInitialController() as! NSWindowController?
        self.windowController?.showWindow(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        self.loadUIIfNeeded()
    }

    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return false
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        switch userActivity.activityType {
        case ChapterActivityType, CSSearchableItemActionType:
            guard let url = self.url(activity: userActivity) else { return false }
            return self.chapterTreeController?.resumeFromActivity(url: url) == true
        default:
            return false
        }
    }

    private func url(activity: NSUserActivity) -> URL? {
        switch activity.activityType {
        case ChapterActivityType:
            guard let urlString = activity.userInfo?["urlString"] as? String else { return nil }
            return URL(string: urlString)
        case CSSearchableItemActionType:
            guard let urlString = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return nil }
            return URL(string: urlString)
        default:
            return nil
        }
    }
}

