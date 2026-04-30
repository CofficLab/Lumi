import Foundation

/// LSP 折叠范围编辑器插件：提供代码折叠
actor LSPFoldingRangeEditorPlugin: SuperPlugin {
    static let id = "LSPFoldingRangeEditor"
    static let displayName = String(localized: "LSP Folding Ranges", table: "LSPFoldingRangeEditor")
    static let description = String(localized: "Provides code folding ranges from the language server.", table: "LSPFoldingRangeEditor")
    static let iconName = "chevron.left.2"
    static let order = 26
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via FoldingRangeProvider
    }
}
