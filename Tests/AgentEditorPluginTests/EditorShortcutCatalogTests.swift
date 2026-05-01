import Testing
@testable import Lumi

@MainActor
struct EditorShortcutCatalogTests {
    @Test
    func effectiveShortcutPrefersCustomBinding() throws {
        let command = try #require(EditorShortcutCatalog.command(id: "builtin.find"))
        let customBindings = [
            command.id: EditorKeybindingEntry(
                commandID: command.id,
                key: "k",
                modifiers: [.command, .option]
            ),
        ]

        let effective = EditorShortcutCatalog.effectiveShortcut(for: command, customBindings: customBindings)

        #expect(effective == EditorCommandShortcut(key: "k", modifiers: [.command, .option]))
    }

    @Test
    func searchMatchesShortcutDisplayText() {
        let results = EditorShortcutCatalog.filteredCommands(query: "⌘⇧P", category: nil)

        #expect(results.contains(where: { $0.id == "builtin.command-palette" }))
    }

    @Test
    func conflictsIncludeDefaultBindings() {
        let candidate = EditorCommandShortcut(key: "p", modifiers: [.command, .shift])

        let conflicts = EditorShortcutCatalog.conflicts(
            for: "builtin.find",
            candidate: candidate,
            customBindings: [:]
        )

        #expect(conflicts.contains(where: { $0.id == "builtin.command-palette" }))
    }
}
