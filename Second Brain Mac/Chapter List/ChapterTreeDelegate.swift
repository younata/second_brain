import Cocoa
import SBKit

final class ChapterTreeDelegate: NSObject, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, toolTipFor cell: NSCell, rect: NSRectPointer,
                     tableColumn: NSTableColumn?, item: Any, mouseLocation: NSPoint) -> String {
        guard let cocoaChapter = item as? CocoaChapter else { return "" }
        return cocoaChapter.chapter.contentURL.absoluteString
    }
}
