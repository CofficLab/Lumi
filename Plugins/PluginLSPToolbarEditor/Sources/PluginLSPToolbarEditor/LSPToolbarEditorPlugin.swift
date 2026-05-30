import Foundation
import EditorService
import LumiCoreKit
/// LSP 工具栏编辑器插件。
///
/// 该插件向编辑器注册 `LSPToolbarContributor`，用于向编辑器工具栏或状态区域贡献 LSP 相关状态项，
/// 例如诊断数量、索引/进度状态、快速操作入口等。
///
/// 本插件主要提供工具栏状态项 Contributor，不直接实现 LSP 请求；具体数据来自 `LSPServiceEditorPlugin`
/// 注册的 LSP 服务、诊断流和进度 Provider。需要工具栏/状态栏 UI 消费 StatusItem contributor 后才会显示。
public actor LSPToolbarEditorPlugin: SuperPlugin {
    public static let shared = LSPToolbarEditorPlugin()
    public static let id = "LSPToolbarEditor"
    public static let displayName = String(localized: "LSP Toolbar", table: "LSPToolbarEditor")
    public static let description = String(localized: "Adds diagnostics, progress, and quick action items to the editor toolbar.", table: "LSPToolbarEditor")
    public static let iconName = "wrench.and.screwdriver"
    public static let order = 19
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerStatusItemContributor(LSPToolbarContributor())
    }
}
