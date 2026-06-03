import Foundation
import EditorService
import LumiCoreKit
/// LSP Sheet 编辑器插件。
///
/// 该插件向编辑器注册 `LSPSheetContributor`，负责提供与 LSP 功能相关的 Sheet/弹窗容器，
/// 例如调用层级结果面板、工作区符号面板等。
///
/// 本插件主要提供“展示容器”，不直接实现具体 LSP 数据请求。实际数据通常由对应 Provider 插件提供，
/// 例如调用层级数据来自 `LSPCallHierarchyEditorPlugin`，工作区符号数据来自
/// `LSPWorkspaceSymbolEditorPlugin`。具体 Sheet 内容视图放在 `Views` 目录中。
public actor LSPSheetsEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = LSPSheetsEditorPlugin()
    public static let id = "LSPSheetsEditor"
    public static let displayName = String(localized: "LSP Sheets", bundle: .module)
    public static let description = String(localized: "Presents LSP sheets such as workspace symbols and call hierarchy.", bundle: .module)
    public static let iconName = "square.on.square"
    public static let order = 17
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerSheetContributor(LSPSheetContributor())
    }
}
