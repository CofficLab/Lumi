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

    @MainActor
    func testEditorStateViewportObservationUpdatesMirroredRanges() {
        let state = EditorState()

        state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 1000)

        XCTAssertEqual(state.viewportVisibleLineRange, 100..<120)
        XCTAssertEqual(state.viewportRenderLineRange, 50..<170)
        XCTAssertEqual(state.viewportRenderController.totalLines, 1000)
    }

    func testViewportFeatureEnabledWhenViewportStartsBeforeLimit() {
        XCTAssertTrue(EditorState.isViewportFeatureEnabled(viewportRange: 500..<800, maxLine: 1_000))
        XCTAssertFalse(EditorState.isViewportFeatureEnabled(viewportRange: 1_000..<1_200, maxLine: 1_000))
    }

    func testViewportFeatureEnabledWhenViewportRangeIsEmpty() {
        XCTAssertTrue(EditorState.isViewportFeatureEnabled(viewportRange: 0..<0, maxLine: 1_000))
    }

    func testLongLineProtectionSuppressesSyntaxHighlightingInLargeModes() {
        XCTAssertTrue(
            EditorState.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 8, length: 20_000)
            )
        )
        XCTAssertFalse(
            EditorState.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .medium,
                longestDetectedLine: LongestDetectedLine(line: 8, length: 20_000)
            )
        )
    }

    func testViewportSyntaxFeatureEnabledWhenViewportWithinLimit() {
        XCTAssertTrue(
            EditorState.isViewportSyntaxFeatureEnabled(
                viewportRange: 200..<400,
                maxLine: 1_000,
                largeFileMode: .medium,
                longestDetectedLine: nil
            )
        )
    }

    func testViewportSyntaxFeatureDisabledWhenLongLineProtectionApplies() {
        XCTAssertFalse(
            EditorState.isViewportSyntaxFeatureEnabled(
                viewportRange: 0..<100,
                maxLine: 10_000,
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 3, length: 15_000)
            )
        )
    }

    @MainActor
    func testEditorStateDisablesCodeActionsWhenViewportSyntaxFeaturesAreDisabled() {
        let state = EditorState()
        state.applyViewportObservation(startLine: 0, endLine: 100, totalLines: 20_000)
        state.largeFileMode = .large
        state.longestDetectedLine = LongestDetectedLine(line: 3, length: 15_000)

        XCTAssertFalse(state.areCodeActionsEnabled)
    }

    @MainActor
    func testEditorStateRenderedRangeHelpers() {
        let state = EditorState()
        state.applyViewportObservation(startLine: 100, endLine: 120, totalLines: 1000)

        XCTAssertTrue(state.isRenderedLine(60))
        XCTAssertFalse(state.isRenderedLine(20))

        state.applyViewportObservation(startLine: 2, endLine: 3, totalLines: 10)
        let shortTable = LineOffsetTable(content: "a\nbb\nccc\ndddd\n")
        XCTAssertTrue(state.isRenderedOffset(2, lineTable: shortTable))
        XCTAssertFalse(state.isRenderedOffset(0, lineTable: shortTable))
        XCTAssertTrue(
            state.intersectsRenderedRange(
                EditorRange(location: 2, length: 2),
                lineTable: shortTable
            )
        )
        XCTAssertFalse(
            state.intersectsRenderedRange(
                EditorRange(location: 0, length: 1),
                lineTable: shortTable
            )
        )

        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 1), matchedText: "a"),
            EditorFindMatch(range: EditorRange(location: 2, length: 2), matchedText: "bb")
        ]
        XCTAssertEqual(state.renderedFindMatches(matches, lineTable: shortTable).count, 1)

        let hints = [
            InlayHintItem(line: 0, character: 0, text: "a", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
            InlayHintItem(line: 2, character: 0, text: "b", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false)
        ]
        XCTAssertEqual(state.renderedInlayHints(hints).count, 1)
    }

    @MainActor
    func testLoadFullFileOverrideDisablesTruncatedPreview() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("large.txt")
        let largeContent = String(repeating: "abcdefg\n", count: 350_000)
        try largeContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(state.isTruncated)
        XCTAssertFalse(state.isEditable)

        state.loadFullFileFromDisk()
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(state.isTruncated)
        XCTAssertFalse(state.canLoadFullFile)
        XCTAssertEqual(state.content?.string, largeContent)
    }
}

#endif
