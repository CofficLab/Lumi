import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// LSP 内联提示编辑器插件
///
/// 该插件对应 LSP `textDocument/inlayHint` 能力，用于在编辑器中显示类型信息、
/// 参数名称等内联提示。语言服务器会根据当前文档返回提示位置和内容。
///
/// 本插件负责把 `InlayHintProvider` 注册到编辑器扩展注册中心。
/// 展示由编辑器内核消费 Provider 数据并渲染。
public enum LSPInlayHintEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "text.badge.star"

    public static let info = LumiPluginInfo(
        id: "LSPInlayHintEditor",
        displayName: LumiPluginLocalization.string("LSP Inlay Hints", bundle: .module),
        description: LumiPluginLocalization.string("Shows inline type annotations and parameter names from the language server.", bundle: .module),
        order: 22
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = InlayHintProvider(lspService: .shared)
        registry.registerInlayHintProvider(provider)
    }
}
