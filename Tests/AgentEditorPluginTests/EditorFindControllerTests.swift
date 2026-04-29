#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorFindControllerTests: XCTestCase {
    func testOpeningPanelPreservesQueryAndShowsPanel() {
        let controller = EditorFindController()
        let state = EditorFindReplaceState(findText: "needle", replaceText: "", isFindPanelVisible: false)

        let updated = controller.stateForOpeningPanel(state)

        XCTAssertEqual(updated.findText, "needle")
        XCTAssertTrue(updated.isFindPanelVisible)
    }

    func testUpdatingOptionsMutatesCopy() {
        let controller = EditorFindController()
        let state = EditorFindReplaceState()

        let updated = controller.stateForUpdatingOptions(state) { options in
            options.isCaseSensitive = true
        }

        XCTAssertTrue(updated.options.isCaseSensitive)
        XCTAssertFalse(state.options.isCaseSensitive)
    }

    func testApplyMatchesResultUpdatesSelectionMetadata() {
        let controller = EditorFindController()
        var state = EditorFindReplaceState()
        let result = EditorFindMatchesResult(
            matches: [EditorFindMatch(range: .init(location: 3, length: 2), matchedText: "ab")],
            selectedMatchIndex: 0,
            selectedMatchRange: .init(location: 3, length: 2)
        )

        controller.applyMatchesResult(result, to: &state)

        XCTAssertEqual(state.resultCount, 1)
        XCTAssertEqual(state.selectedMatchIndex, 0)
        XCTAssertEqual(state.selectedMatchRange, .init(location: 3, length: 2))
    }
}
#endif
