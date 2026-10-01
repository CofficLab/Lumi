import XCTest
@testable import KitMail

final class KitMailTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertEqual(KitMail().self, KitMail().self)
    }
}
