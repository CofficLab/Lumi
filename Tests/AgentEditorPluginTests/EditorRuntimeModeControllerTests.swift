#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorRuntimeModeControllerTests: XCTestCase {
    func testViewportObservationUpdatesMirroredRanges() {
        let controller = EditorRuntimeModeController()

        let observation = controller.applyViewportObservation(
            startLine: 100,
            endLine: 120,
            totalLines: 1_000,
            areInlayHintsEnabled: false,
            requestInlayHints: {},
            clearInlayHints: {}
        )

        XCTAssertEqual(observation.visibleLineRange, 100..<120)
        XCTAssertEqual(observation.renderLineRange, 50..<170)
        XCTAssertEqual(controller.viewportRenderController.totalLines, 1_000)
    }

    func testRuntimeFeatureHelpersFollowLongLineProtectionRules() {
        XCTAssertTrue(
            EditorRuntimeModeController.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 8, length: 20_000)
            )
        )
        XCTAssertFalse(
            EditorRuntimeModeController.isViewportSyntaxFeatureEnabled(
                viewportRange: 0..<100,
                maxLine: 10_000,
                largeFileMode: .large,
                longestDetectedLine: LongestDetectedLine(line: 3, length: 15_000)
            )
        )
        XCTAssertTrue(
            EditorRuntimeModeController.isViewportSyntaxFeatureEnabled(
                viewportRange: 200..<400,
                maxLine: 1_000,
                largeFileMode: .medium,
                longestDetectedLine: nil
            )
        )
    }

    func testRenderedRangeHelpersFilterMatchesAndHints() {
        let controller = EditorRuntimeModeController()
        let renderRange = 0..<3
        let lineTable = LineOffsetTable(content: "a\nbb\nccc\ndddd\n")
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 1), matchedText: "a"),
            EditorFindMatch(range: EditorRange(location: 9, length: 4), matchedText: "dddd")
        ]
        let hints = [
            InlayHintItem(line: 0, character: 0, text: "a", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false),
            InlayHintItem(line: 4, character: 0, text: "b", kind: nil, tooltip: nil, paddingLeft: false, paddingRight: false)
        ]

        XCTAssertTrue(controller.isRenderedLine(2, renderRange: renderRange))
        XCTAssertFalse(controller.isRenderedLine(4, renderRange: renderRange))
        XCTAssertEqual(
            controller.renderedFindMatches(matches, renderRange: renderRange, lineTable: lineTable).count,
            1
        )
        XCTAssertEqual(
            controller.renderedInlayHints(hints, renderRange: renderRange).count,
            1
        )
    }
}
#endif
