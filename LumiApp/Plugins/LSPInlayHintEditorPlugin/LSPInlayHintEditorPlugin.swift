import Foundation

/// LSP 内联提示编辑器插件：显示类型推断和参数名提示
actor LSPInlayHintEditorPlugin: SuperPlugin {
    static let id = "LSPInlayHintEditor"
    static let displayName = String(localized: "LSP Inlay Hints", table: "LSPInlayHintEditor")
    static let description = String(localized: "Displays type inference and parameter name hints inline.", table: "LSPInlayHintEditor")
    static let iconName = "textformat.size"
    static let order = 22
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via InlayHintProvider
    }
}
