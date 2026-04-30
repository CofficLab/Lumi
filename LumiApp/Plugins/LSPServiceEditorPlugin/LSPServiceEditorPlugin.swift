import Foundation

/// LSP 服务编辑器插件：提供核心 LSP 集成（补全、hover、诊断等）
actor LSPServiceEditorPlugin: SuperPlugin {
    static let id = "LSPServiceEditor"
    static let displayName = String(localized: "LSP Service", table: "LSPServiceEditor")
    static let description = String(localized: "Provides the core Language Server Protocol integration including completion, hover, and diagnostics.", table: "LSPServiceEditor")
    static let iconName = "server.rack"
    static let order = 5
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // LSP 补全/悬停/代码动作等能力通过 LSPService 单例直接调用，
        // 不走 EditorExtensionContributor 路径（因为补全/悬停上下文缺少 fileURI）。
        // 此插件主要确保 LSP 服务在编辑器加载时可用。
    }
}
