import Foundation

@objc(LumiLSPServiceEditorPlugin)
@MainActor
final class LSPServiceEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.service"
    let displayName: String = String(localized: "LSP Service", table: "LSPServiceEditor")
    override var description: String { String(localized: "Provides the core Language Server Protocol integration including completion, hover, and diagnostics.", table: "LSPServiceEditor") }
    let order: Int = 5

    func register(into registry: EditorExtensionRegistry) {
        // LSP 补全/悬停/代码动作等能力通过 LSPService 单例直接调用，
        // 不走 EditorExtensionContributor 路径（因为补全/悬停上下文缺少 fileURI）。
        // 此插件主要确保 LSP 服务在编辑器加载时可用。
    }
}
