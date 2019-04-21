import Cocoa
import SBKit

@objc final class CocoaChapter: NSObject {
    @objc let title: String
    @objc let children: [CocoaChapter]
    @objc let childrenCount: Int
    @objc let isLeaf: Bool

    let chapter: Chapter

    init(chapter: Chapter) {
        self.chapter = chapter
        self.title = chapter.title
        self.children = chapter.subchapters.map(CocoaChapter.init)
        self.childrenCount = self.children.count
        self.isLeaf = self.children.isEmpty
        super.init()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CocoaChapter else { return false }
        return other.title == self.title && other.children == self.children
    }
}
