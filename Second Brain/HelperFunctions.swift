import Foundation

// Helper function for determining if running under test.
// Mostly useful for disabling animations.
func isTest(_ file: StaticString = #file, line: Int = #line) -> Bool {
    return NSClassFromString("XCTestCase") != nil
}
