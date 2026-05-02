import Foundation

/// LSP 签名帮助编辑器插件：显示函数签名提示
actor LSPSignatureHelpEditorPlugin: SuperPlugin {
    static let id = "LSPSignatureHelpEditor"
    static let displayName = String(localized: "LSP Signature Help", table: "LSPSignatureHelpEditor")
    static let description = String(localized: "Shows function signature hints when typing parameters.", table: "LSPSignatureHelpEditor")
    static let iconName = "text.badge.plus"
    static let order = 23
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let provider = SignatureHelpProvider(lspService: .shared)
        registry.registerSignatureHelpProvider(provider)
    }
}
