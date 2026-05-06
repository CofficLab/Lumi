#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorServiceUtilitiesTests: XCTestCase {

    func testLineOffsetTableLineContainingUTF16Offset() {
        let table = LineOffsetTable(content: "ab\ncd\nef")

        XCTAssertEqual(table.lineContaining(utf16Offset: 0), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 2), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 3), 1)
        XCTAssertEqual(table.lineContaining(utf16Offset: 5), 1)
        XCTAssertEqual(table.lineContaining(utf16Offset: 6), 2)
        XCTAssertEqual(table.lineContaining(utf16Offset: 8), 2)
    }

    func testLineOffsetTableHandlesTerminalNewline() {
        let table = LineOffsetTable(content: "ab\n")

        XCTAssertEqual(table.lineContaining(utf16Offset: 2), 0)
        XCTAssertEqual(table.lineContaining(utf16Offset: 3), 1)
        XCTAssertEqual(table.lineCount, 2)
    }

    func testLineOffsetTableSupportsUTF16OffsetsForUnicodeContent() {
        let table = LineOffsetTable(content: "😀a\nb")

        XCTAssertEqual(table.lineStart(line: 0), 0)
        XCTAssertEqual(table.lineStart(line: 1), 3)
        XCTAssertEqual(table.utf16Offset(line: 0, character: 2), 2)
        XCTAssertEqual(table.utf16Offset(line: 1, character: 1), 4)
        XCTAssertEqual(table.totalUTF16Length, 4)
    }

    func testLineOffsetTableRejectsOutOfBoundsQueries() {
        let table = LineOffsetTable(content: "abc")

        XCTAssertNil(table.lineStart(line: -1))
        XCTAssertNil(table.lineStart(line: 1))
        XCTAssertNil(table.utf16Offset(line: 0, character: -1))
        XCTAssertNil(table.utf16Offset(line: 2, character: 0))
        XCTAssertNil(table.lineContaining(utf16Offset: -1))
        XCTAssertNil(table.lineContaining(utf16Offset: 4))
    }

    func testLargeFileModeBoundaryValues() {
        XCTAssertEqual(LargeFileMode.mode(for: 0), .normal)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.mediumThreshold - 1), .normal)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.mediumThreshold), .medium)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.largeThreshold), .large)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.megaThreshold), .mega)
    }

    func testLargeFileModeFeatureFlagsByTier() {
        let medium = LargeFileMode.mode(for: 5 * 1024 * 1024)
        let large = LargeFileMode.mode(for: 20 * 1024 * 1024)
        let mega = LargeFileMode.mode(for: 60 * 1024 * 1024)

        XCTAssertTrue(medium.isSemanticTokensDisabled)
        XCTAssertFalse(medium.isInlayHintsDisabled)
        XCTAssertFalse(medium.isReadOnly)
        XCTAssertEqual(medium.maxSyntaxHighlightLines, 50_000)

        XCTAssertTrue(large.isInlayHintsDisabled)
        XCTAssertTrue(large.isFoldingDisabled)
        XCTAssertTrue(large.isMinimapDisabled)
        XCTAssertTrue(large.isLongLineProtectionEnabled)
        XCTAssertFalse(large.isReadOnly)
        XCTAssertEqual(large.maxSyntaxHighlightLines, 10_000)

        XCTAssertTrue(mega.isReadOnly)
        XCTAssertEqual(mega.maxSyntaxHighlightLines, 1_000)
    }

    func testLongLineDetectorFindsFirstLineExceedingThreshold() {
        let longLine = String(repeating: "a", count: 15_000)
        let text = "header\n\(longLine)\nfooter"

        let result = LongLineDetector.findLongestLine(in: text)

        XCTAssertEqual(result?.line, 1)
        XCTAssertEqual(result?.length, 15_000)
    }

    func testLongLineDetectorReturnsNilBelowThreshold() {
        let text = String(repeating: "b", count: 9_999)
        XCTAssertNil(LongLineDetector.findLongestLine(in: text))
    }

    func testLongLineDetectorHonorsCustomLimit() {
        let text = "short\n123456"

        let result = LongLineDetector.findLongestLine(in: text, limit: 5)

        XCTAssertEqual(result, LongestDetectedLine(line: 1, length: 6))
    }
}
#endif
