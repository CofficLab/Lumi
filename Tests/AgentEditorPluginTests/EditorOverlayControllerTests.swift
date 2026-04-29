#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorOverlayControllerTests: XCTestCase {
    func testHoverOverlayTextRespectsPresentationFlag() {
        let controller = EditorOverlayController()

        XCTAssertNil(controller.hoverOverlayText(shouldPresent: false, hoverText: " demo "))
        XCTAssertEqual(controller.hoverOverlayText(shouldPresent: true, hoverText: " demo "), "demo")
    }

    func testCodeActionOverlayActionsHideWhenDisabled() {
        let controller = EditorOverlayController()
        let actions = [
            CodeActionItem(
                title: "Fix",
                kind: "quickfix",
                payload: .plugin(EditorCodeActionSuggestion(
                    id: "fix",
                    title: "Fix",
                    command: "editor.fix",
                    priority: 0
                )),
                isPreferred: false
            )
        ]

        XCTAssertTrue(controller.codeActionOverlayActions(shouldPresent: false, actions: actions).isEmpty)
        XCTAssertEqual(controller.codeActionOverlayActions(shouldPresent: true, actions: actions).count, 1)
    }
}
#endif
