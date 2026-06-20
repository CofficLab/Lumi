import Foundation
import Testing
import EditorService
@testable import EditorMinimapContextMenuPlugin

@Test func packageLoads() async throws {
    #expect(EditorMinimapContextMenuPlugin.id == "EditorMinimapContextMenu")
}

@MainActor
@Test func registersMinimapContextMenuContributor() async throws {
    let plugin = EditorMinimapContextMenuPlugin.shared
    let registry = EditorExtensionRegistry()

    #expect(plugin.providesEditorExtensions)
    plugin.registerEditorExtensions(into: registry)

    #expect(registry.commandContributorsCount == 1)
}

@MainActor
@Test func contributorHasStableIdentifier() async throws {
    let contributor = MinimapContextMenuCommandContributor()
    #expect(contributor.id == "builtin.minimap.context-menu")
}
