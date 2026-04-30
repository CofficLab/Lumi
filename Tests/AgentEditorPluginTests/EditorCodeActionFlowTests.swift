#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorCodeActionFlowTests: XCTestCase {
    func testPresentCodeActionPanelPrefersPreferredAction() {
        let state = EditorState()
        state.codeActionProvider.actions = [
            makeAction(title: "Wrap in print", preferred: false),
            makeAction(title: "Import Module", preferred: true),
        ]

        let didPresent = state.presentCodeActionPanel(preferPreferred: true)

        XCTAssertTrue(didPresent)
        XCTAssertTrue(state.isCodeActionPanelPresented)
        XCTAssertEqual(state.selectedCodeActionIndex, 1)
        XCTAssertEqual(state.selectedCodeAction?.title, "Import Module")
    }

    func testReconcileCodeActionPanelKeepsSelectionAcrossRefresh() {
        let state = EditorState()
        state.codeActionProvider.actions = [
            makeAction(title: "Fix One", preferred: false),
            makeAction(title: "Fix Two", preferred: false),
        ]
        _ = state.presentCodeActionPanel(preferPreferred: false)
        state.selectCodeAction(at: 1)

        state.codeActionProvider.actions = [
            makeAction(title: "Fix One", preferred: false),
            makeAction(title: "Fix Two", preferred: false),
            makeAction(title: "Fix Three", preferred: true),
        ]
        state.reconcileCodeActionPanelState()

        XCTAssertEqual(state.selectedCodeActionIndex, 1)
        XCTAssertEqual(state.selectedCodeAction?.title, "Fix Two")
    }

    private func makeAction(title: String, preferred: Bool) -> CodeActionItem {
        CodeActionItem(
            title: title,
            kind: "quickfix",
            payload: .plugin(EditorCodeActionSuggestion(
                id: title,
                title: title,
                command: "builtin.test",
                priority: 0
            )),
            isPreferred: preferred
        )
    }
}
#endif
