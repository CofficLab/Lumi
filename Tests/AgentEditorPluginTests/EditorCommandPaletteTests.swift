#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorCommandPaletteTests: XCTestCase {
    override func tearDown() {
        AppSettingStore.saveEditorRecentCommandIDs([])
        AppSettingStore.saveEditorCommandUsageCounts([:])
        AppSettingStore.saveEditorCommandPaletteCategory(nil)
        super.tearDown()
    }

    func testEditorCommandSectionsAreOrderedByCategory() {
        let state = EditorState()

        let sections = state.editorCommandSections()

        XCTAssertFalse(sections.isEmpty)
        XCTAssertEqual(sections.first?.category, .edit)
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

    func testFrequentCommandSuggestionsPreferHigherUsageCounts() {
        let state = EditorState()

        state.recordCommandExecution(id: "builtin.find")
        state.recordCommandExecution(id: "builtin.find")
        state.recordCommandExecution(id: "builtin.rename-symbol")
        state.recordCommandExecution(id: "builtin.rename-symbol")
        state.recordCommandExecution(id: "builtin.rename-symbol")

        let frequent = state.frequentCommandSuggestions(limit: 2)

        XCTAssertEqual(frequent.map(\.id), [
            "builtin.rename-symbol",
            "builtin.find"
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

    func testEditorCommandSectionsReflectUpdatedCustomShortcut() {
        let store = EditorKeybindingStore.shared
        store.removeBinding(commandID: "builtin.command-palette")
        addTeardownBlock {
            Task { @MainActor in
                EditorKeybindingStore.shared.removeBinding(commandID: "builtin.command-palette")
            }
        }

        let state = EditorState()
        store.setBinding(commandID: "builtin.command-palette", key: "k", modifiers: [.command, .option])

        let sections = state.editorCommandSections(matching: "⌘⌥K")
        let commandIDs = sections.flatMap(\.commands).map(\.id)

        XCTAssertEqual(commandIDs, ["builtin.command-palette"])
    }

    func testEditorCommandSectionsCanMatchCategoryRawValue() {
        let state = EditorState()

        let sections = state.editorCommandSections(matching: "workbench")
        let commandIDs = sections.flatMap(\.commands).map(\.id)

        XCTAssertTrue(commandIDs.contains("builtin.command-palette"))
        XCTAssertTrue(commandIDs.contains("builtin.split-right"))
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
        XCTAssertEqual(model.frequentCommands.map(\.id), [])
        XCTAssertEqual(model.sections.flatMap(\.commands).map(\.id), ["builtin.find"])
    }

    func testPresentationModelSeparatesFrequentCommandsFromSections() {
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
            ),
            .init(
                id: "builtin.command-palette",
                title: "Command Palette",
                systemImage: "command",
                category: EditorCommandCategory.workbench.rawValue,
                order: 0,
                isEnabled: true,
                action: {}
            )
        ]

        let model = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: ["builtin.command-palette"],
            commandUsageCounts: ["builtin.find": 3, "builtin.rename-symbol": 1, "builtin.command-palette": 4]
        )

        XCTAssertEqual(model.recentCommands.map(\.id), ["builtin.command-palette"])
        XCTAssertEqual(model.frequentCommands.map(\.id), ["builtin.find"])
        XCTAssertEqual(model.sections.flatMap(\.commands).map(\.id), ["builtin.rename-symbol"])
    }

    func testPreferredCommandPaletteCategoryPersists() {
        let state = EditorState()

        state.setPreferredCommandPaletteCategory(.workbench)

        XCTAssertEqual(state.preferredCommandPaletteCategory(), .workbench)
        XCTAssertEqual(AppSettingStore.loadEditorCommandPaletteCategory(), EditorCommandCategory.workbench.rawValue)
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
