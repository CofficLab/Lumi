import Foundation
import EditorService
import LumiCoreKit
/// LSP 折叠范围编辑器插件。
///
/// 该插件负责把 `FoldingRangeProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/foldingRange` 的代码折叠范围数据。
///
/// 本插件不提供独立 View。折叠范围会被编辑器内核和源码编辑器 UI 消费，
/// 用于显示折叠箭头、折叠区域或恢复折叠状态。完整能力依赖 LSP 服务插件和
/// 当前语言服务器对 folding range 的支持。
public actor LSPFoldingRangeEditorPlugin: SuperPlugin {
    public static let shared = LSPFoldingRangeEditorPlugin()
    public static let id = "LSPFoldingRangeEditor"
    public static let displayName = String(localized: "LSP Folding Ranges", table: "LSPFoldingRangeEditor")
    public static let description = String(localized: "Provides code folding ranges from the language server.", table: "LSPFoldingRangeEditor")
    public static let iconName = "chevron.left.2"
    public static let order = 26
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = FoldingRangeProvider(lspService: .shared)
        registry.registerFoldingRangeProvider(provider)
    }
}
