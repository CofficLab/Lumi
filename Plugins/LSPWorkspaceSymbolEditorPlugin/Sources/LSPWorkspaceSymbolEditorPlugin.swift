import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP 工作区符号编辑器插件。
///
/// 该插件负责把 `WorkspaceSymbolProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `workspace/symbol` 的全工作区符号搜索能力。
/// 同时它还注册 `LSPWorkspaceSymbolQuickOpenContributor`，让 Quick Open 或命令入口可以触发工作区符号搜索。
///
/// 本插件目录中的 `Views/WorkspaceSymbolSearchView.swift` 提供搜索框和结果列表展示组件；
/// 主入口负责注册 Provider 和 Quick Open contributor，具体 Sheet/弹窗容器通常由
/// `LSPSheetsEditorPlugin` 或其它消费 Workspace Symbol Provider 的 UI 提供。
public enum LSPWorkspaceSymbolEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "magnifyingglass"

    public static let info = LumiPluginInfo(
        id: "LSPWorkspaceSymbolEditor",
        displayName: LumiPluginLocalization.string("LSP Workspace Symbols", bundle: .module),
        description: LumiPluginLocalization.string("Provides workspace-wide symbol search.", bundle: .module),
        order: 24
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = WorkspaceSymbolProvider(lspService: .shared)
        registry.registerWorkspaceSymbolProvider(provider)
        registry.registerQuickOpenContributor(LSPWorkspaceSymbolQuickOpenContributor())
    }
}
