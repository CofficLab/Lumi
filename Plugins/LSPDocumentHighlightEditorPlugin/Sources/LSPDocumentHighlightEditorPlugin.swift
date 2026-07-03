import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP 文档高亮编辑器插件。
///
/// 该插件负责把 `DocumentHighlightProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/documentHighlight` 的符号引用高亮能力。
/// 当光标停留在某个符号上时，Provider 会请求语言服务器返回当前文档内相关引用范围。
///
/// 本插件不提供独立 View。高亮结果会作为 `HighlightProviding` 数据源或文档高亮 Provider
/// 被源码编辑器消费，最终由编辑器高亮系统把引用范围渲染到文本上。
public enum LSPDocumentHighlightEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "highlighter"

    public static let info = LumiPluginInfo(
        id: "LSPDocumentHighlightEditor",
        displayName: LumiPluginLocalization.string("LSP Document Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Highlights all references of the symbol at cursor position.", bundle: .module),
        order: 21
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = DocumentHighlightProvider(lspService: .shared)
        registry.registerDocumentHighlightProvider(provider)
    }
}
