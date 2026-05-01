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
        // 创建 LSP 协调器并注册到 Registry — 内核通过协议接口使用，不直接引用插件类型
        let coordinator = LSPCoordinator(lspService: .shared)
        registry.registerSuperEditorLSPClient(coordinator)

        // 注册语义 Token 提供者（同时遵循 HighlightProviding）
        let semanticTokenProvider = SemanticTokenHighlightProvider(
            lspService: .shared,
            uriProvider: { [weak coordinator] in coordinator?.fileURI }
        )
        registry.registerSemanticTokenProvider(semanticTokenProvider)
    }
}
