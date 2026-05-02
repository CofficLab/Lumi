import Foundation

/// LSP 调用层级编辑器插件：显示符号的调用关系
actor LSPCallHierarchyEditorPlugin: SuperPlugin {
    static let id = "LSPCallHierarchyEditor"
    static let displayName = String(localized: "LSP Call Hierarchy", table: "LSPCallHierarchyEditor")
    static let description = String(localized: "Shows incoming and outgoing call hierarchy for symbols.", table: "LSPCallHierarchyEditor")
    static let iconName = "diagram"
    static let order = 25
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let provider = CallHierarchyProvider(lspService: .shared)
        registry.registerCallHierarchyProvider(provider)
    }
}
