@testable import Second_Brain

final class SimpleHTMLWrapper: HTMLWrapper {
    var wrapCalls: [String] = []
    func wrap(html: String) -> String {
        self.wrapCalls.append(html)
        return "<html><body>\(html)</body></html>"
    }
}
