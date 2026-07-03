import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP Sheet 编辑器插件。
///
/// 该插件向编辑器注册 `LSPSheetContributor`，负责提供与 LSP 功能相关的 Sheet/弹窗容器，
/// 例如调用层级结果面板、工作区符号面板等。
///
/// 本插件主要提供“展示容器”，不直接实现具体 LSP 数据请求。实际数据通常由对应 Provider 插件提供，
/// 例如调用层级数据来自 `LSPCallHierarchyEditorPlugin`，工作区符号数据来自
/// `LSPWorkspaceSymbolEditorPlugin`。具体 Sheet 内容视图放在 `Views` 目录中。
public enum LSPSheetsEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "square.on.square"

    public static let info = LumiPluginInfo(
        id: "LSPSheetsEditor",
        displayName: LumiPluginLocalization.string("LSP Sheets", bundle: .module),
        description: LumiPluginLocalization.string("Presents LSP sheets such as workspace symbols and call hierarchy.", bundle: .module),
        order: 17
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerSheetContributor(LSPSheetContributor())
    }
}
