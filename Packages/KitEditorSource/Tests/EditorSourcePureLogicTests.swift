import XCTest
import AppKit
import SwiftUI
@testable import EditorSource

final class EditorSourcePureLogicTests: XCTestCase {
    func testBracketPairsMatching() {
        for bracket in ["{", "}", "[", "]", "(", ")", "\"", "'"] {
            XCTAssertTrue(BracketPairs.matches(bracket), "expected \(bracket) to match")
        }
        XCTAssertFalse(BracketPairs.matches("x"))
        XCTAssertFalse(BracketPairs.matches(""))
        XCTAssertEqual(BracketPairs.emphasisValues.count, 3)
    }

    func testIndentOptionStringAndCount() {
        XCTAssertEqual(IndentOption.spaces(count: 4).stringValue, "    ")
        XCTAssertEqual(IndentOption.spaces(count: 0).stringValue, "")
        XCTAssertEqual(IndentOption.tab.stringValue, "\t")
        XCTAssertEqual(IndentOption.spaces(count: 3).charCount, 3)
        XCTAssertEqual(IndentOption.tab.charCount, 1)
        XCTAssertEqual(IndentOption.spaces(count: 2), .spaces(count: 2))
        XCTAssertNotEqual(IndentOption.spaces(count: 2), .spaces(count: 3))
        XCTAssertNotEqual(IndentOption.spaces(count: 1), .tab)
        XCTAssertEqual(IndentOption.tab, .tab)
    }

    func testColorHexRoundTrip() {
        let color = Color(hex: 0x112233)
        XCTAssertEqual(color.hex, 0x112233)
        XCTAssertEqual(color.hexString, "#112233")

        let prefixed = Color(hex: "#1D2E3F")
        XCTAssertEqual(prefixed.hex, 0x1D2E3F)

        XCTAssertEqual(Color(hex: "no-hex").hex, 0)
    }

    func testStringNSRangeSubscript() {
        let text = "hello world"
        XCTAssertEqual(text[NSRange(location: 0, length: 5)], "hello")
        XCTAssertEqual(text[NSRange(location: 6, length: 5)], "world")
        XCTAssertEqual(text[NSRange(location: 0, length: 0)], "")
        // 越界或非法范围返回 nil 而不是崩溃
        XCTAssertNil(text[NSRange(location: 0, length: 100)])
        XCTAssertNil(text[NSRange(location: 0, length: Int.max)])
    }

    func testStringNSRangeSubscriptWithEmoji() {
        let text = "a😀b"
        // emoji 占 2 个 utf16 单位
        XCTAssertEqual(text[NSRange(location: 1, length: 2)], "😀")
        XCTAssertNil(text[NSRange(location: 1, length: 4)])
    }
}
