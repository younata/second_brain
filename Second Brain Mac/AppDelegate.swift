import Cocoa
import SBKit
import Swinject
import SwinjectStoryboard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private var storyboard: SwinjectStoryboard!
    private var windowController: NSWindowController!
    private lazy var injector: Container = {
        let container = Container()
        SBKit.register(container)
        Second_Brain.register(container)
        return container
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }

        self.storyboard = SwinjectStoryboard.create(name: "UI", bundle: nil, container: self.injector)

        self.windowController = storyboard.instantiateInitialController() as! NSWindowController?
        self.windowController?.showWindow(self)
    }
}

