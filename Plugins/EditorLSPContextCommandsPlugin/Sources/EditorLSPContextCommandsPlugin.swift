import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP 上下文命令编辑器插件。
///
/// 该插件向编辑器注册一组与 Language Server Protocol 相关的命令入口，
/// 例如跳转定义、跳转声明、查找引用、重命名、格式化、工作区符号和调用层级。
///
/// 本插件只提供"命令入口"和命令触发逻辑，不直接实现 LSP 请求本身，也不负责展示复杂结果 UI。
/// 具体数据能力由 `LSPServiceEditorPlugin` 以及各功能 Provider 插件提供；
/// 例如调用层级数据来自 `LSPCallHierarchyEditorPlugin`，工作区符号数据来自
/// `LSPWorkspaceSymbolEditorPlugin`。
///
/// 该插件没有独立 View；它通过 `SuperEditorCommandContributor` 把命令贡献给命令面板、
/// 右键菜单或其它消费编辑器命令的 UI。
public enum EditorLSPContextCommandsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "command"

    public static let info = LumiPluginInfo(
        id: "EditorLSPContextCommands",
        displayName: LumiPluginLocalization.string("LSP Context Commands", bundle: .module),
        description: LumiPluginLocalization.string("Adds LSP context commands like go to definition and rename.", bundle: .module),
        order: 15
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(EditorLSPContextCommandContributor())
    }
}
