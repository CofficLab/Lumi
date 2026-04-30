#if canImport(XCTest)
import XCTest
import CodeEditTextView
@testable import Lumi

@MainActor
final class EditorCommandControllerTests: XCTestCase {
    func testRecordExecutionPromotesMostRecentAndCapsLength() {
        let controller = EditorCommandController()
        var recent = (0..<12).map { "cmd.\($0)" }
        var usageCounts: [String: Int] = [:]

        controller.recordExecution(id: "cmd.4", recentCommandIDs: &recent, commandUsageCounts: &usageCounts)
        XCTAssertEqual(recent.first, "cmd.4")
        XCTAssertEqual(recent.count, 12)
        XCTAssertEqual(usageCounts["cmd.4"], 1)

        controller.recordExecution(id: "cmd.new", recentCommandIDs: &recent, commandUsageCounts: &usageCounts)
        XCTAssertEqual(recent.first, "cmd.new")
        XCTAssertEqual(recent.count, 12)
        XCTAssertFalse(recent.contains("cmd.11"))
        XCTAssertEqual(usageCounts["cmd.new"], 1)
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

    func testPresentationModelBuildsFrequentCommandsFromUsageCounts() {
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
            recentCommandIDs: [],
            commandUsageCounts: ["editor.open": 3, "editor.save": 1],
            query: ""
        )

        XCTAssertEqual(model.frequentCommands.map(\.id), ["editor.open"])
        XCTAssertEqual(model.sections.flatMap(\.commands).map(\.id), ["editor.save"])
    }

    func testInvocationContextUsesProvidedTextViewSelectionCoordinates() {
        let state = EditorState()
        state.detectedLanguage = .swift
        let textView = TextView(string: "alpha\nbeta\n")
        textView.selectionManager.setSelectedRange(NSRange(location: 7, length: 2))

        let invocationContext = state.editorCommandInvocationContext(for: textView)

        XCTAssertEqual(invocationContext.legacyContext.languageId, "swift")
        XCTAssertTrue(invocationContext.legacyContext.hasSelection)
        XCTAssertEqual(invocationContext.legacyContext.line, 1)
        XCTAssertEqual(invocationContext.legacyContext.character, 1)
        XCTAssertEqual(invocationContext.registryContext.line, 1)
        XCTAssertEqual(invocationContext.registryContext.character, 1)
        XCTAssertTrue(invocationContext.registryContext.hasSelection)
    }
}
#endif
