import Quick
import Nimble
import Swinject
import FutureHTTP
@testable import SBKit

final class InjectorModuleSpec: QuickSpec {
    override func spec() {
        var subject: Container!

        beforeEach {
            subject = Container()

            SBKit.register(subject)
        }

        describe("OperationQueueJumper") {
            it("exists") {
                expect(subject.resolve(OperationQueueJumper.self)).toNot(beNil())
            }
        }

        describe("ActivityService") {
            it("is a SearchActivityService") {
                expect(subject.resolve(ActivityService.self)).to(beAKindOf(SearchActivityService.self))
            }

            it("is a singleton") {
                expect(subject.resolve(ActivityService.self)).to(beIdenticalTo(subject.resolve(ActivityService.self)))
            }
        }

        describe("BookService") {
            let url = URL(string: "https://example.com")!
            it("is a SyncBookService with a CoreDataBookService under it") {
                expect(subject.resolve(BookService.self, argument: url)).to(beAKindOf(SyncBookService.self))

                guard let bookService = subject.resolve(BookService.self, argument: url) as? SyncBookService else {
                    return
                }

                expect(bookService.bookService).to(beAKindOf(CoreDataBookService.self))
            }

            it("is a singleton") {
                expect(subject.resolve(BookService.self, argument: url)).to(beIdenticalTo(subject.resolve(BookService.self, argument: url)))
            }
        }

        describe("SyncService") {
            it("exists") {
                expect(subject.resolve(SyncService.self)).toNot(beNil())
            }
        }

        describe("HTTPClient") {
            it("is a url session") {
                expect(subject.resolve(HTTPClient.self)).to(beIdenticalTo(URLSession.shared))
            }
        }

        describe("ActivityService") {
            it("is a SearchActivityService") {
                expect(subject.resolve(ActivityService.self)).to(beAKindOf(SearchActivityService.self))
            }
        }
    }
}
