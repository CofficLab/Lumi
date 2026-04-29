#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorCommandControllerTests: XCTestCase {
    func testRecordExecutionPromotesMostRecentAndCapsLength() {
        let controller = EditorCommandController()
        var recent = (0..<12).map { "cmd.\($0)" }

        controller.recordExecution(id: "cmd.4", recentCommandIDs: &recent)
        XCTAssertEqual(recent.first, "cmd.4")
        XCTAssertEqual(recent.count, 12)

        controller.recordExecution(id: "cmd.new", recentCommandIDs: &recent)
        XCTAssertEqual(recent.first, "cmd.new")
        XCTAssertEqual(recent.count, 12)
        XCTAssertFalse(recent.contains("cmd.11"))
    }

    func testPresentationModelBuildsRecentCommands() {
        let controller = EditorCommandController()
        let suggestions = [
            EditorCommandSuggestion(
                id: "editor.open",
                title: "Open",
                systemImage: "arrowshape.turn.up.right",
                category: EditorCommandCategory.navigation.rawValue,
                order: 0,
                isEnabled: true,
                action: {}
            ),
            EditorCommandSuggestion(
                id: "editor.save",
                title: "Save",
                systemImage: "square.and.arrow.down",
                category: EditorCommandCategory.save.rawValue,
                order: 1,
                isEnabled: true,
                action: {}
            )
        ]

        let model = controller.presentationModel(
            from: suggestions,
            recentCommandIDs: ["editor.save"],
            query: ""
        )

        XCTAssertEqual(model.recentCommands.first?.id, "editor.save")
        XCTAssertFalse(model.sections.isEmpty)
    }
}
#endif
