import UIKit
import Swinject
import SBKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private lazy var injector: Container = {
        let container = Container()
        SBKit.register(container)
        Second_Brain.register(container)
        return container
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.makeKeyAndVisible()

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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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

