import Foundation
import os
/// LSP 上下文命令编辑器插件。
///
/// 该插件向编辑器注册一组与 Language Server Protocol 相关的命令入口，
/// 例如跳转定义、跳转声明、查找引用、重命名、格式化、工作区符号和调用层级。
///
/// 本插件只提供“命令入口”和命令触发逻辑，不直接实现 LSP 请求本身，也不负责展示复杂结果 UI。
/// 具体数据能力由 `LSPServiceEditorPlugin` 以及各功能 Provider 插件提供；
/// 例如调用层级数据来自 `LSPCallHierarchyEditorPlugin`，工作区符号数据来自
/// `LSPWorkspaceSymbolEditorPlugin`。
///
/// 该插件没有独立 View；它通过 `SuperEditorCommandContributor` 把命令贡献给命令面板、
/// 右键菜单或其它消费编辑器命令的 UI。
actor EditorLSPContextCommandsPlugin: SuperPlugin, SuperLog {
    static let shared = EditorLSPContextCommandsPlugin()
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose: Bool = false

    static let id = "EditorLSPContextCommands"
    static let displayName = String(localized: "LSP Context Commands", table: "EditorLSPContextCommands")
    static let description = String(localized: "Adds LSP context commands like go to definition and rename.", table: "EditorLSPContextCommands")
    static let iconName = "command"
    static let order = 15
    static let enable = true
    static var isConfigurable: Bool { false }
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lsp-context-commands")

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let contributor = EditorLSPContextCommandContributor()
        registry.registerCommandContributor(contributor)
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)注册 CommandContributor 完成, contributorId=\(contributor.id)")
            }
        }
    }
}
