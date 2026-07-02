import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP 折叠范围编辑器插件。
///
/// 该插件负责把 `FoldingRangeProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/foldingRange` 的代码折叠范围数据。
///
/// 本插件不提供独立 View。折叠范围会被编辑器内核和源码编辑器 UI 消费，
/// 用于显示折叠箭头、折叠区域或恢复折叠状态。完整能力依赖 LSP 服务插件和
/// 当前语言服务器对 folding range 的支持。
public enum LSPFoldingRangeEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.2"

    public static let info = LumiPluginInfo(
        id: "LSPFoldingRangeEditor",
        displayName: LumiPluginLocalization.string("LSP Folding Ranges", bundle: .module),
        description: LumiPluginLocalization.string("Provides code folding ranges from the language server.", bundle: .module),
        order: 26
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = FoldingRangeProvider(lspService: .shared)
        registry.registerFoldingRangeProvider(provider)
    }
}
