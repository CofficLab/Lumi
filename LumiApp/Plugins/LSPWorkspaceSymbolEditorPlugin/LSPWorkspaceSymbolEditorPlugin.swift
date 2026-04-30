import Foundation

/// LSP 工作区符号编辑器插件：提供工作区范围的符号搜索
actor LSPWorkspaceSymbolEditorPlugin: SuperPlugin {
    static let id = "LSPWorkspaceSymbolEditor"
    static let displayName = String(localized: "LSP Workspace Symbols", table: "LSPWorkspaceSymbolEditor")
    static let description = String(localized: "Provides workspace-wide symbol search.", table: "LSPWorkspaceSymbolEditor")
    static let iconName = "magnifyingglass"
    static let order = 24
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerQuickOpenContributor(LSPWorkspaceSymbolQuickOpenContributor())
    }
}
