import Cocoa
import SBKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var chapterTreeController: NSTreeController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

