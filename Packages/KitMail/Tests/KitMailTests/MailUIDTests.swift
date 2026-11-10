import XCTest
@testable import KitMail

final class MailUIDTests: XCTestCase {
    func testValidatedAcceptsProtocolRange() {
        XCTAssertEqual(MailUID.validated(1), 1)
        XCTAssertEqual(MailUID.validated(4_294_967_295), UInt32.max)
    }

    func testValidatedRejectsZeroAndOutOfRange() {
        XCTAssertNil(MailUID.validated(0))
        XCTAssertNil(MailUID.validated(MailUID.maximum + 1))
        XCTAssertNil(MailUID.validated(UInt64.max))
    }
}
