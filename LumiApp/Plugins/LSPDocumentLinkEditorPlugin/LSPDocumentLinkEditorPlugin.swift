import Foundation

/// LSP 文档链接编辑器插件：使 URL 和文件路径可点击
actor LSPDocumentLinkEditorPlugin: SuperPlugin {
    static let id = "LSPDocumentLinkEditor"
    static let displayName = String(localized: "LSP Document Links", table: "LSPDocumentLinkEditor")
    static let description = String(localized: "Makes URLs and file paths clickable in the editor.", table: "LSPDocumentLinkEditor")
    static let iconName = "link"
    static let order = 29
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via DocumentLinkProvider
    }
}
