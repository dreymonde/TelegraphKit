import XCTest
@testable import TelegraphKit

final class TelegraphKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TelegraphKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
