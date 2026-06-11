import Foundation
import EditorService
import LumiCoreKit
/// LSP 文档链接编辑器插件。
///
/// 该插件对应 LSP 的 `textDocument/documentLink` 和 `documentLink/resolve` 能力，
/// 用于识别文档中的 URL、文件路径或语言服务器提供的可跳转链接。
///
/// 当前主入口不直接注册 Provider；链接数据由同目录下的 `DocumentLinkProvider` 维护，
/// 展示组件位于 `Views/DocumentLinkView.swift`。该视图只负责把链接范围显示为可点击文本，
/// 实际打开链接或跳转由上层编辑器 UI 注入。
///
/// 完整启用该能力需要 LSP 服务可用，且当前语言服务器支持 document link 相关 LSP 方法。
public actor LSPDocumentLinkEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = LSPDocumentLinkEditorPlugin()
    public static let id = "LSPDocumentLinkEditor"
    public static let displayName = LumiPluginLocalization.string("LSP Document Links", bundle: .module)
    public static let description = LumiPluginLocalization.string("Makes URLs and file paths clickable in the editor.", bundle: .module)
    public static let iconName = "link"
    public static let order = 29
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        // Provided via DocumentLinkProvider
    }
}
