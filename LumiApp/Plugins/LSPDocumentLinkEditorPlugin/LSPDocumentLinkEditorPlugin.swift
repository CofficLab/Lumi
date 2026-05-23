import Foundation
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
actor LSPDocumentLinkEditorPlugin: SuperPlugin {
    static let shared = LSPDocumentLinkEditorPlugin()
    static let id = "LSPDocumentLinkEditor"
    static let displayName = String(localized: "LSP Document Links", table: "LSPDocumentLinkEditor")
    static let description = String(localized: "Makes URLs and file paths clickable in the editor.", table: "LSPDocumentLinkEditor")
    static let iconName = "link"
    static let order = 29
    static let enable = true
    static var isConfigurable: Bool { false }
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // Provided via DocumentLinkProvider
    }
}
