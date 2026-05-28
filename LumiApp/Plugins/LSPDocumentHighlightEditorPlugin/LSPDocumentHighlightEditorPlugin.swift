import Foundation
/// LSP 文档高亮编辑器插件。
///
/// 该插件负责把 `DocumentHighlightProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/documentHighlight` 的符号引用高亮能力。
/// 当光标停留在某个符号上时，Provider 会请求语言服务器返回当前文档内相关引用范围。
///
/// 本插件不提供独立 View。高亮结果会作为 `HighlightProviding` 数据源或文档高亮 Provider
/// 被源码编辑器消费，最终由编辑器高亮系统把引用范围渲染到文本上。
actor LSPDocumentHighlightEditorPlugin: SuperPlugin {
    static let shared = LSPDocumentHighlightEditorPlugin()
    static let id = "LSPDocumentHighlightEditor"
    static let displayName = String(localized: "LSP Document Highlight", table: "LSPDocumentHighlightEditor")
    static let description = String(localized: "Highlights all references of the symbol at cursor position.", table: "LSPDocumentHighlightEditor")
    static let iconName = "highlighter"
    static let order = 21
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let provider = DocumentHighlightProvider(lspService: .shared)
        registry.registerDocumentHighlightProvider(provider)
    }
}
