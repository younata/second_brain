import SBKit
import UIKit
import Swinject
import CoreSpotlight

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private lazy var injector: Container = {
        let container = Container()
        SBKit.register(container)
        Second_Brain.register(container)
        return container
    }()

    private var chapterListController: ChapterListViewController? {
        guard let splitView = self.window?.rootViewController as? UISplitViewController else { return nil }
        guard let navController = splitView.viewControllers.first as? UINavigationController else { return nil }
        return navController.viewControllers.first as? ChapterListViewController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.makeKeyAndVisible()
        window.backgroundColor = UIColor(named: "Ayu Background")

        guard !isTest() else {
            window.rootViewController = UIViewController()
            return true
        }

        guard let bookURLString = Bundle.main.infoDictionary?["BookURL"] as? String,
            let bookURL = URL(string: bookURLString) else {
                dump(Bundle.main.infoDictionary)
                window.rootViewController = UIViewController()
                let alert = UIAlertController(title: "No book url specified", message: "Unable to load book", preferredStyle: .alert)
                window.rootViewController?.present(alert, animated: true, completion: nil)
                return true
        }

        applyTheme()

        let splitController = UISplitViewController()
        splitController.viewControllers = [
            UINavigationController(rootViewController: self.injector.resolve(ChapterListViewController.self, argument: bookURL)!)
        ]
        splitController.preferredDisplayMode = .allVisible

        window.rootViewController = splitController

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        switch userActivity.activityType {
        case ChapterActivityType:
            return self.chapterListController?.resume(chapterActivity: userActivity) == true
        case CSSearchableItemActionType:
            return self.chapterListController?.resume(searchActivity: userActivity) == true
        default:
            return false
        }
    }
}

func applyTheme() {
    guard let navColor = UIColor(named: "Ayu Navigation"),
        let navButtonColor = UIColor(named: "Ayu NavColor"),
        let textColor = UIColor(named: "Ayu Text")
        else { return }
    UINavigationBar.appearance().barTintColor = navColor
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: textColor]
    UINavigationBar.appearance().tintColor = navButtonColor

    UIApplication.shared.statusBarStyle = .lightContent
}

