import Cocoa

protocol URLOpener {
    @discardableResult func open(_ url: URL) -> Bool
}

extension NSWorkspace: URLOpener {}
