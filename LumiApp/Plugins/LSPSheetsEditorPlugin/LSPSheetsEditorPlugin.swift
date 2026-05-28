import Foundation
/// LSP Sheet 编辑器插件。
///
/// 该插件向编辑器注册 `LSPSheetContributor`，负责提供与 LSP 功能相关的 Sheet/弹窗容器，
/// 例如调用层级结果面板、工作区符号面板等。
///
/// 本插件主要提供“展示容器”，不直接实现具体 LSP 数据请求。实际数据通常由对应 Provider 插件提供，
/// 例如调用层级数据来自 `LSPCallHierarchyEditorPlugin`，工作区符号数据来自
/// `LSPWorkspaceSymbolEditorPlugin`。具体 Sheet 内容视图放在 `Views` 目录中。
actor LSPSheetsEditorPlugin: SuperPlugin {
    static let shared = LSPSheetsEditorPlugin()
    static let id = "LSPSheetsEditor"
    static let displayName = String(localized: "LSP Sheets", table: "LSPSheetsEditor")
    static let description = String(localized: "Presents LSP sheets such as workspace symbols and call hierarchy.", table: "LSPSheetsEditor")
    static let iconName = "square.on.square"
    static let order = 17
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerSheetContributor(LSPSheetContributor())
    }
}
