#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorCommandPaletteTests: XCTestCase {
    func testEditorCommandSectionsAreOrderedByCategory() {
        let state = EditorState()

        let sections = state.editorCommandSections()

        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.first?.category, .find)
        XCTAssertTrue(sections.contains(where: { $0.category == .workbench }))
        XCTAssertTrue(sections.contains(where: { $0.category == .navigation }))
    }

    func testRecentCommandSuggestionsPreferMostRecentExecutionOrder() {
        let state = EditorState()

        state.recordCommandExecution(id: "builtin.rename-symbol")
        state.recordCommandExecution(id: "builtin.find")
        state.recordCommandExecution(id: "builtin.workspace-symbols")

        let recent = state.recentCommandSuggestions(limit: 3)

        XCTAssertEqual(recent.map(\.id), [
            "builtin.workspace-symbols",
            "builtin.find",
            "builtin.rename-symbol"
        ])
    }

    func testRecentCommandSuggestionsFilterByQuery() {
        let state = EditorState()

        state.recordCommandExecution(id: "builtin.find")
        state.recordCommandExecution(id: "builtin.workspace-symbols")
        state.recordCommandExecution(id: "builtin.rename-symbol")

        let filtered = state.recentCommandSuggestions(matching: "rename", limit: 5)

        XCTAssertEqual(filtered.map(\.id), ["builtin.rename-symbol"])
    }

    func testEditorCommandSectionsCanMatchShortcutDisplayText() {
        let state = EditorState()

        let sections = state.editorCommandSections(matching: "⌘⇧P")
        let commandIDs = sections.flatMap(\.commands).map(\.id)

        XCTAssertEqual(commandIDs, ["builtin.command-palette"])
    }

    func testEditorCommandSectionsCanMatchCategoryRawValue() {
        let state = EditorState()

        let sections = state.editorCommandSections(matching: "workbench")
        let commandIDs = sections.flatMap(\.commands).map(\.id)

        XCTAssertTrue(commandIDs.contains("builtin.command-palette"))
        XCTAssertTrue(commandIDs.contains("builtin.open-editors-panel"))
    }

    func testEditorCommandSectionsCanMatchCommandIdentifier() {
        let state = EditorState()

        let sections = state.editorCommandSections(matching: "builtin.rename-symbol")
        let commandIDs = sections.flatMap(\.commands).map(\.id)

        XCTAssertEqual(commandIDs, ["builtin.rename-symbol"])
    }

    func testPresentationModelSeparatesRecentCommandsFromSections() {
        let suggestions: [EditorCommandSuggestion] = [
            .init(
                id: "builtin.find",
                title: "Find",
                systemImage: "magnifyingglass",
                category: EditorCommandCategory.find.rawValue,
                order: 0,
                isEnabled: true,
                action: {}
            ),
            .init(
                id: "builtin.rename-symbol",
                title: "Rename Symbol",
                systemImage: "pencil",
                category: EditorCommandCategory.navigation.rawValue,
                order: 0,
                isEnabled: true,
                action: {}
            )
        ]

        let model = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: ["builtin.rename-symbol"]
        )

        XCTAssertEqual(model.recentCommands.map(\.id), ["builtin.rename-symbol"])
        XCTAssertEqual(model.sections.flatMap(\.commands).map(\.id), ["builtin.find"])
    }

    func testEditorCommandSectionsForContextUseSharedPresentationModel() {
        let state = EditorState()
        let context = EditorCommandContext(
            languageId: "swift",
            hasSelection: false,
            line: 0,
            character: 0
        )

        let sections = state.editorCommandSections(for: context, textView: nil)
        let model = state.editorCommandPresentationModel(for: context, textView: nil)

        XCTAssertEqual(sections.map(\.id), model.sections.map(\.id))
    }

    func testPresentationModelSortsCommandsByOrderBeforeTitle() {
        let suggestions: [EditorCommandSuggestion] = [
            .init(
                id: "builtin.z-last",
                title: "Z Last",
                systemImage: "z.circle",
                category: EditorCommandCategory.workbench.rawValue,
                order: 200,
                isEnabled: true,
                action: {}
            ),
            .init(
                id: "builtin.a-later",
                title: "A Later",
                systemImage: "a.circle",
                category: EditorCommandCategory.workbench.rawValue,
                order: 150,
                isEnabled: true,
                action: {}
            ),
            .init(
                id: "builtin.b-earlier",
                title: "B Earlier",
                systemImage: "b.circle",
                category: EditorCommandCategory.workbench.rawValue,
                order: 150,
                isEnabled: true,
                action: {}
            )
        ]

        let model = EditorCommandPresentationModel.build(from: suggestions, recentCommandIDs: [])

        XCTAssertEqual(model.sections.first?.commands.map(\.id), [
            "builtin.a-later",
            "builtin.b-earlier",
            "builtin.z-last"
        ])
    }

    func testPresentationModelCanFilterByAllowedCategories() {
        let suggestions: [EditorCommandSuggestion] = [
            .init(
                id: "builtin.find",
                title: "Find",
                systemImage: "magnifyingglass",
                category: EditorCommandCategory.find.rawValue,
                order: 100,
                isEnabled: true,
                action: {}
            ),
            .init(
                id: "builtin.rename-symbol",
                title: "Rename Symbol",
                systemImage: "pencil",
                category: EditorCommandCategory.navigation.rawValue,
                order: 200,
                isEnabled: true,
                action: {}
            )
        ]

        let model = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: ["builtin.find", "builtin.rename-symbol"],
            allowedCategories: [.navigation]
        )

        XCTAssertEqual(model.recentCommands.map(\.id), ["builtin.rename-symbol"])
        XCTAssertEqual(model.sections.flatMap(\.commands).map(\.id), [])
    }

    func testPresentationModelSortsByCategoryBeforeTitle() {
        let suggestions: [EditorCommandSuggestion] = [
            .init(
                id: "builtin.workbench-a",
                title: "A Workbench",
                systemImage: "sidebar.left",
                category: EditorCommandCategory.workbench.rawValue,
                order: 100,
                isEnabled: true,
                action: {}
            ),
            .init(
                id: "builtin.navigation-z",
                title: "Z Navigation",
                systemImage: "arrow.turn.right.up",
                category: EditorCommandCategory.navigation.rawValue,
                order: 100,
                isEnabled: true,
                action: {}
            )
        ]

        let model = EditorCommandPresentationModel.build(from: suggestions, recentCommandIDs: [])

        XCTAssertEqual(model.sections.map(\.category), [.navigation, .workbench])
        XCTAssertEqual(model.flattenedCommands.map(\.id), [
            "builtin.navigation-z",
            "builtin.workbench-a"
        ])
    }

    func testContextPresentationModelCanFilterByCategories() {
        let state = EditorState()
        let context = EditorCommandContext(
            languageId: "swift",
            hasSelection: false,
            line: 0,
            character: 0
        )

        let model = state.editorCommandPresentationModel(
            for: context,
            textView: nil,
            categories: [.workbench]
        )

        let commandIDs = model.flattenedCommands.map(\.id)
        XCTAssertTrue(commandIDs.contains("builtin.command-palette"))
        XCTAssertTrue(commandIDs.contains("builtin.split-right"))
        XCTAssertFalse(commandIDs.contains("builtin.find"))
        XCTAssertFalse(commandIDs.contains("builtin.format-document"))
    }
}
#endif
