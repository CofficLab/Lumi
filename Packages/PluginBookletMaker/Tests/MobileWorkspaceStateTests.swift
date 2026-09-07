import Foundation
import XCTest
@testable import BookletMakerPlugin

@MainActor
final class MobileWorkspaceStateTests: XCTestCase {

    func testStartsInWelcomeWithBookletToolAndNoPresentation() {
        let state = MobileWorkspaceState()
        XCTAssertEqual(state.phase, .welcome)
        XCTAssertEqual(state.selectedTool, .booklet)
        XCTAssertNil(state.presentation)
    }

    func testDocumentLifecycleReachesReadyAndCloses() {
        let state = MobileWorkspaceState()
        state.beginImport()
        XCTAssertEqual(state.phase, .importing)
        state.documentReady()
        XCTAssertEqual(state.phase, .ready)
        state.closeDocument()
        XCTAssertEqual(state.phase, .welcome)
    }

    func testToolSwitchOnlyAllowedInIdlePhases() {
        let state = MobileWorkspaceState()
        state.selectTool(.split)
        XCTAssertEqual(state.selectedTool, .booklet, "Tool switch must be ignored in welcome")

        state.documentReady()
        state.selectTool(.split)
        XCTAssertEqual(state.selectedTool, .split)

        state.beginGenerating()
        state.selectTool(.booklet)
        XCTAssertEqual(state.selectedTool, .split, "Tool switch must be ignored while generating")
    }

    func testGenerationCancellationTransitions() {
        let state = MobileWorkspaceState()
        state.documentReady()
        state.beginGenerating()
        XCTAssertEqual(state.phase, .generating)
        state.beginCancelling()
        XCTAssertEqual(state.phase, .cancelling)
        state.generationCancelled()
        XCTAssertEqual(state.phase, .ready)
    }

    func testFailedImportKeepsDocumentForRetry() {
        let state = MobileWorkspaceState()
        state.documentReady()
        state.beginImport()
        state.documentFailed()
        XCTAssertEqual(state.phase, .failed)
        state.dismissFailure()
        XCTAssertEqual(state.phase, .ready)
    }

    func testPresentationIsSingle() {
        let state = MobileWorkspaceState()
        state.documentReady()
        state.present(.help)
        XCTAssertEqual(state.presentation, .help)

        state.present(.bookletOptions)
        XCTAssertEqual(state.presentation, .bookletOptions)

        state.present(nil)
        XCTAssertNil(state.presentation)
    }

    func testPresentationIDsAreDistinctPerKind() {
        let first = MobileWorkspaceState.Presentation.help
        let second = MobileWorkspaceState.Presentation.bookletOptions
        let rename = MobileWorkspaceState.Presentation.splitRename(
            PDFSplitSegment(index: 1, startPage: 1, endPage: 8)
        )
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.id, rename.id)
    }
}
