import Quick
import Nimble
@testable import SBKit

func assertCoreDataChapter(chapter: CoreDataChapter, book: CoreDataBook?, url: URL, title: String, etag: String?, content: String?, file: FileString = #file, line: UInt = #line) {
    if let cdbook = book {
        expect(chapter.book, file: file, line: line).to(equal(cdbook))
    } else {
        expect(chapter.book, file: file, line: line).to(beNil())
    }
    expect(chapter.contentURL, file: file, line: line).to(equal(url))
    expect(chapter.title, file: file, line: line).to(equal(title))
    if content == nil {
        expect(chapter.content, file: file, line: line).to(beNil())
    } else {
        expect(chapter.content, file: file, line: line).to(equal(content))
    }
    if etag == nil {
        expect(chapter.etag, file: file, line: line).to(beNil())
    } else {
        expect(chapter.etag, file: file, line: line).to(equal(etag))
    }
}

