import Foundation
import EditorService
import LumiCoreKit

/// LSP 服务编辑器插件
///
/// 这是 LSP 插件组的核心基础插件，负责把 `LSPCoordinator` 注册为编辑器的
/// `SuperEditorLSPClient`，并把 `LSPService` 连接到当前编辑器扩展注册中心。
/// 它提供文档打开/关闭/变更同步、补全、Hover、定义跳转、引用、重命名、格式化、诊断、
/// 语义 Token 等基础 Language Server Protocol 能力。
///
/// 本插件还注册 `SemanticTokenHighlightProvider`，使编辑器可以消费 LSP semantic tokens 作为
/// 语义高亮来源。目录中的 `Views` 仅包含状态栏、进度、Hover 等轻量展示组件；
/// 主入口本身主要负责服务和 Provider 注册。
///
/// 其它 LSP 插件通常依赖本插件提供的 `LSPService.shared` 和注册后的 LSP client。
public enum LSPServiceEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "server.rack"

    public static let info = LumiPluginInfo(
        id: "LSPServiceEditor",
        displayName: LumiPluginLocalization.string("LSP Service", bundle: .module),
        description: LumiPluginLocalization.string("Provides the core Language Server Protocol integration including completion, hover, and diagnostics.", bundle: .module),
        order: 5
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        // 创建 LSP 协调器并注册到 Registry — 内核通过协议接口使用，不直接引用插件类型
        let coordinator = LSPCoordinator(lspService: .shared)
        registry.registerSuperEditorLSPClient(coordinator)
        registry.registerDiagnosticsProvider(LSPService.shared)

        // 注入 registry 到 LSPService（替代 EditorExtensionRegistry.shared）
        LSPService.shared.configureRegistry(registry)

        // 注册语义 Token 提供者（同时遵循 HighlightProviding）
        let semanticTokenProvider = SemanticTokenHighlightProvider(
            lspService: .shared,
            uriProvider: { [weak coordinator] in coordinator?.fileURI }
        )
        registry.registerSemanticTokenProvider(semanticTokenProvider)
    }

    public static func lifecycle(_ event: LumiPluginLifecycle) {
        if case .willUnregister = event {
            Task { @MainActor in
                LSPService.shared.stopAll()
            }
        }
    }
}
