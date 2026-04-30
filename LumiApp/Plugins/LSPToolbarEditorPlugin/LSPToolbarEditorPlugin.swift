import Foundation

/// LSP 工具栏编辑器插件：添加诊断、进度和快速操作到工具栏
actor LSPToolbarEditorPlugin: SuperPlugin {
    static let id = "LSPToolbarEditor"
    static let displayName = String(localized: "LSP Toolbar", table: "LSPToolbarEditor")
    static let description = String(localized: "Adds diagnostics, progress, and quick action items to the editor toolbar.", table: "LSPToolbarEditor")
    static let iconName = "wrench.and.screwdriver"
    static let order = 19
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerStatusItemContributor(LSPToolbarContributor())
    }
}
