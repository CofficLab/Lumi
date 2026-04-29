#if canImport(XCTest)
import XCTest
@testable import Lumi

final class LineOffsetTableTests: XCTestCase {

    func testLineContainingUTF16Offset() {
        let table = LineOffsetTable(content: "ab\ncd\nef")

        XCTAssertEqual(table.lineContaining(utf16Offset: 0), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 2), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 3), 1)
        XCTAssertEqual(table.lineContaining(utf16Offset: 5), 1)
        XCTAssertEqual(table.lineContaining(utf16Offset: 6), 2)
        XCTAssertEqual(table.lineContaining(utf16Offset: 8), 2)
    }

    func testLineContainingHandlesTerminalNewline() {
        let table = LineOffsetTable(content: "ab\n")

        XCTAssertEqual(table.lineContaining(utf16Offset: 2), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 3), 1)
    }
}
#endif
