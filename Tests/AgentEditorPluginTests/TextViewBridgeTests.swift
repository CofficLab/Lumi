#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
import CodeEditTextView
@testable import Lumi

@MainActor
final class TextViewBridgeTests: XCTestCase {
    func testLspPositionMapsUtf16OffsetsAcrossLines() {
        let bridge = TextViewBridge()
        let text = "ab\nc"

        let start = bridge.lspPosition(utf16Offset: 0, in: text)
        let lineBreak = bridge.lspPosition(utf16Offset: 2, in: text)
        let secondLine = bridge.lspPosition(utf16Offset: 3, in: text)

        XCTAssertEqual(start?.line, 0)
        XCTAssertEqual(start?.character, 0)
        XCTAssertEqual(lineBreak?.line, 0)
        XCTAssertEqual(lineBreak?.character, 2)
        XCTAssertEqual(secondLine?.line, 1)
        XCTAssertEqual(secondLine?.character, 0)
    }

    func testLspRangeBuildsExpectedLineAndCharacterPairs() {
        let bridge = TextViewBridge()
        let text = "hello\nworld"

        let range = bridge.lspRange(from: NSRange(location: 3, length: 4), in: text)

        XCTAssertEqual(range?.start.line, 0)
        XCTAssertEqual(range?.start.character, 3)
        XCTAssertEqual(range?.end.line, 1)
        XCTAssertEqual(range?.end.character, 1)
    }

    func testConsumeSuppressFlagResetsAfterRead() {
        let bridge = TextViewBridge()
        let began = bridge.beginNativeReplacement(
            range: NSRange(location: 0, length: 1),
            text: "x",
            in: makeTextView(text: "abc"),
            captureUndoState: { nil }
        )

        XCTAssertTrue(began)
        XCTAssertNotNil(bridge.consumeNativeReplacement(text: "x"))
        XCTAssertTrue(bridge.consumeSuppressNextTextDidChangeReconciliation())
        XCTAssertFalse(bridge.consumeSuppressNextTextDidChangeReconciliation())
    }

    private func makeTextView(text: String) -> TextView {
        TextView(string: text)
    }
}
#endif
