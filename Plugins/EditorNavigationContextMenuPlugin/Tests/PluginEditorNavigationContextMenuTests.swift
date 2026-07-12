import Foundation
import Testing
import EditorService
@testable import EditorNavigationContextMenuPlugin

@Test func packageLoads() async throws {
    #expect(EditorNavigationContextMenuPlugin.id == "EditorNavigationContextMenu")
}

@MainActor
@Test func registersNavigationContextMenuContributor() async throws {
    let plugin = EditorNavigationContextMenuPlugin.shared
    let registry = EditorExtensionRegistry()

    #expect(plugin.providesEditorExtensions)
    plugin.registerEditorExtensions(into: registry)

    #expect(registry.commandContributorsCount == 1)
}

@MainActor
@Test func contributorHasStableIdentifier() async throws {
    let contributor = NavigationContextMenuCommandContributor()
    #expect(contributor.id == "builtin.navigation.context-menu")
}

@MainActor
@Test func contributorProvidesNavigationCommands() async throws {
    let contributor = NavigationContextMenuCommandContributor()
    let context = EditorCommandContext(
        languageId: "swift",
        hasSelection: false,
        line: 1,
        character: 1
    )

    let commands = contributor.provideCommands(
        context: context,
        state: EditorState(),
        textView: nil
    )

    #expect(commands.isEmpty, "No commands should be returned when textView is nil")
}