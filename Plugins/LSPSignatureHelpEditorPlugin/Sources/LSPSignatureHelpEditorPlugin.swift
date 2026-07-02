import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// LSP 签名帮助编辑器插件
///
/// 该插件对应 LSP `textDocument/signatureHelp` 能力，用于在编辑器中显示函数签名的
/// 参数信息提示。当用户在函数调用括号内输入时，会触发签名帮助请求。
///
/// 本插件负责把 `SignatureHelpProvider` 注册到编辑器扩展注册中心。
/// 展示由编辑器内核消费 Provider 数据并渲染签名提示 UI。
public enum LSPSignatureHelpEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "function"

    public static let info = LumiPluginInfo(
        id: "LSPSignatureHelpEditor",
        displayName: LumiPluginLocalization.string("LSP Signature Help", bundle: .module),
        description: LumiPluginLocalization.string("Shows parameter information and function signatures from the language server.", bundle: .module),
        order: 23
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = SignatureHelpProvider(lspService: .shared)
        registry.registerSignatureHelpProvider(provider)
    }
}
