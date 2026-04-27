#if canImport(XCTest)
import XCTest
@testable import Lumi

final class LargeFileModeTests: XCTestCase {

    func testNormalMode() {
        let mode = LargeFileMode.mode(for: 500 * 1024) // 500KB
        XCTAssertEqual(mode, .normal)
        XCTAssertFalse(mode.isSemanticTokensDisabled)
        XCTAssertFalse(mode.isInlayHintsDisabled)
        XCTAssertFalse(mode.isFoldingDisabled)
        XCTAssertFalse(mode.isMinimapDisabled)
        XCTAssertFalse(mode.isReadOnly)
    }

    func testMediumMode() {
        let mode = LargeFileMode.mode(for: 5 * 1024 * 1024) // 5MB
        XCTAssertEqual(mode, .medium)
        XCTAssertTrue(mode.isSemanticTokensDisabled)
        XCTAssertFalse(mode.isInlayHintsDisabled)
        XCTAssertFalse(mode.isFoldingDisabled)
        XCTAssertFalse(mode.isMinimapDisabled)
        XCTAssertFalse(mode.isReadOnly)
        XCTAssertEqual(mode.maxSyntaxHighlightLines, 50_000)
    }

    func testLargeMode() {
        let mode = LargeFileMode.mode(for: 20 * 1024 * 1024) // 20MB
        XCTAssertEqual(mode, .large)
        XCTAssertTrue(mode.isSemanticTokensDisabled)
        XCTAssertTrue(mode.isInlayHintsDisabled)
        XCTAssertTrue(mode.isFoldingDisabled)
        XCTAssertTrue(mode.isMinimapDisabled)
        XCTAssertFalse(mode.isReadOnly)
        XCTAssertEqual(mode.maxSyntaxHighlightLines, 10_000)
    }

    func testMegaMode() {
        let mode = LargeFileMode.mode(for: 60 * 1024 * 1024) // 60MB
        XCTAssertEqual(mode, .mega)
        XCTAssertTrue(mode.isSemanticTokensDisabled)
        XCTAssertTrue(mode.isInlayHintsDisabled)
        XCTAssertTrue(mode.isFoldingDisabled)
        XCTAssertTrue(mode.isMinimapDisabled)
        XCTAssertTrue(mode.isReadOnly)
        XCTAssertEqual(mode.maxSyntaxHighlightLines, 1_000)
    }

    func testBoundaryValues() {
        XCTAssertEqual(LargeFileMode.mode(for: 0), .normal)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.mediumThreshold - 1), .normal)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.mediumThreshold), .medium)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.largeThreshold), .large)
        XCTAssertEqual(LargeFileMode.mode(for: LargeFileMode.megaThreshold), .mega)
    }
}

final class LongLineDetectorTests: XCTestCase {

    func testNoLongLine() {
        let text = "short\nline\nhere\n"
        XCTAssertNil(LongLineDetector.findLongestLine(in: text))
    }

    func testLongLineDetected() {
        let longLine = String(repeating: "a", count: 15_000)
        let text = "header\n\(longLine)\nfooter"
        let result = LongLineDetector.findLongestLine(in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.line, 1)
        XCTAssertEqual(result?.length, 15_000)
    }

    func testLongLineAtThreshold() {
        let exactLine = String(repeating: "x", count: 10_000)
        let text = exactLine
        let result = LongLineDetector.findLongestLine(in: text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.length, 10_000)
    }

    func testBelowThreshold() {
        let shortLine = String(repeating: "b", count: 9_999)
        let text = shortLine
        XCTAssertNil(LongLineDetector.findLongestLine(in: text))
    }

    func testEmptyString() {
        XCTAssertNil(LongLineDetector.findLongestLine(in: ""))
    }

    func testSingleCharacter() {
        XCTAssertNil(LongLineDetector.findLongestLine(in: "a"))
    }
}

final class ViewportRenderControllerTests: XCTestCase {

    func testInitialValues() {
        let controller = ViewportRenderController()
        XCTAssertEqual(controller.visibleStartLine, 0)
        XCTAssertEqual(controller.visibleEndLine, 0)
        XCTAssertEqual(controller.totalLines, 0)
        XCTAssertEqual(controller.bufferSize, 50)
    }

    func testRenderRangeWithBuffer() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 100, endLine: 120, totalLines: 1000)

        XCTAssertEqual(controller.renderStartLine, 50)  // 100 - 50
        XCTAssertEqual(controller.renderEndLine, 170)   // 120 + 50
    }

    func testRenderRangeClampedAtStart() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 10, endLine: 30, totalLines: 1000)

        XCTAssertEqual(controller.renderStartLine, 0)  // max(0, 10-50)
        XCTAssertEqual(controller.renderEndLine, 80)   // 30 + 50
    }

    func testRenderRangeClampedAtEnd() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 980, endLine: 1000, totalLines: 1000)

        XCTAssertEqual(controller.renderStartLine, 930) // 980 - 50
        XCTAssertEqual(controller.renderEndLine, 1000)  // min(1000, 1050)
    }

    func testIsLineVisible() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 100, endLine: 120, totalLines: 1000)

        XCTAssertTrue(controller.isLineVisible(100))
        XCTAssertTrue(controller.isLineVisible(119))
        XCTAssertTrue(controller.isLineVisible(50))   // buffer zone
        XCTAssertTrue(controller.isLineVisible(169))  // buffer zone
        XCTAssertFalse(controller.isLineVisible(49))
        XCTAssertFalse(controller.isLineVisible(170))
    }

    func testShouldDebounceUpdate() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 100, endLine: 120, totalLines: 1000)

        // Small change should debounce
        XCTAssertTrue(controller.shouldDebounceUpdate(from: 102, to: 118))

        // Large change should not debounce
        XCTAssertFalse(controller.shouldDebounceUpdate(from: 200, to: 220))
    }
}

#endif
