import Foundation
import EditorService
import LumiCoreKit
/// LSP 签名帮助编辑器插件。
///
/// 该插件负责把 `SignatureHelpProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/signatureHelp` 的函数/方法签名提示能力。
/// 当用户输入 `(`、`,`、`<` 等触发字符时，Provider 会请求语言服务器返回当前调用签名、
/// 参数列表和当前激活参数。
///
/// 本插件目录中的 `Views/SignatureHelpView.swift` 负责渲染签名帮助浮层内容；
/// 主入口只注册 Provider，具体显示时机和位置由编辑器 Overlay 或消费 Provider 的 UI 决定。
public actor LSPSignatureHelpEditorPlugin: SuperPlugin {
    public static let shared = LSPSignatureHelpEditorPlugin()
    public static let id = "LSPSignatureHelpEditor"
    public static let displayName = String(localized: "LSP Signature Help", table: "LSPSignatureHelpEditor")
    public static let description = String(localized: "Shows function signature hints when typing parameters.", table: "LSPSignatureHelpEditor")
    public static let iconName = "text.badge.plus"
    public static let order = 23
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let provider = SignatureHelpProvider(lspService: .shared)
        registry.registerSignatureHelpProvider(provider)
    }
}
