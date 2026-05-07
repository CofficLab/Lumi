import Foundation

/// LSP 文档颜色编辑器插件：显示颜色预览
actor LSPDocumentColorEditorPlugin: SuperPlugin {
    static let id = "LSPDocumentColorEditor"
    static let displayName = String(localized: "LSP Document Colors", table: "LSPDocumentColorEditor")
    static let description = String(localized: "Displays color swatches for color literals from the language server.", table: "LSPDocumentColorEditor")
    static let iconName = "paintpalette"
    static let order = 28
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via DocumentColorProvider
    }
}
