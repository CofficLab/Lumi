import Foundation

/// LSP 侧面板编辑器插件：提供 references 和 problems 面板
actor LSPSidePanelsEditorPlugin: SuperPlugin {
    static let id = "LSPSidePanelsEditor"
    static let displayName = String(localized: "LSP Side Panels", table: "LSPSidePanelsEditor")
    static let description = String(localized: "Provides references and problems side panels.", table: "LSPSidePanelsEditor")
    static let iconName = "sidebar.right"
    static let order = 16
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerSidePanelContributor(LSPSidePanelContributor())
    }
}
