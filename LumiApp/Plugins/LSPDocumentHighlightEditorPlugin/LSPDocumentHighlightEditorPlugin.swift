import Foundation

/// LSP 文档高亮编辑器插件：高亮光标处符号的所有引用
actor LSPDocumentHighlightEditorPlugin: SuperPlugin {
    static let id = "LSPDocumentHighlightEditor"
    static let displayName = String(localized: "LSP Document Highlight", table: "LSPDocumentHighlightEditor")
    static let description = String(localized: "Highlights all references of the symbol at cursor position.", table: "LSPDocumentHighlightEditor")
    static let iconName = "highlighter"
    static let order = 21
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via DocumentHighlightProvider
    }
}
