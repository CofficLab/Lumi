import Foundation
import EditorService
import LumiCoreKit
import os
import SwiftUI

/// LSP 调用层级编辑器插件。
///
/// 该插件负责把 `CallHierarchyProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 Language Server Protocol 的 Call Hierarchy 数据能力。
/// 当用户在某个函数、方法或类型符号上触发调用层级查询时，Provider 会通过 LSP 请求：
///
/// - `textDocument/prepareCallHierarchy`：确定当前光标处可查询的调用层级根符号。
/// - `callHierarchy/incomingCalls`：查询哪些符号调用了当前符号。
/// - `callHierarchy/outgoingCalls`：查询当前符号调用了哪些符号。
///
/// 本插件目录中也包含用于展示调用层级结果的 SwiftUI 视图组件，例如
/// `CallHierarchyTreeView` 和 `CallHierarchyRowView`。这些视图属于调用层级功能的结果展示组件，
/// 但本插件主入口不会自行注册应用级 UI 入口，例如侧边栏、底部面板、工具栏按钮或 Sheet contributor。
///
/// 通常情况下：命令入口由 `EditorLSPContextCommandsPlugin` 提供，Sheet/面板容器由
/// `LSPSheetsEditorPlugin` 或其它消费 `SuperEditorCallHierarchyProvider` 的编辑器 UI 提供，
/// 本插件则负责提供数据和可复用的结果展示视图。
///
/// 要完整测试该能力，需要同时启用 LSP 服务、调用层级 Provider、触发命令的入口以及展示结果的 UI 容器，
/// 并确保当前语言服务器支持上述 Call Hierarchy LSP 方法。
public enum LSPCallHierarchyEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "diagram"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lsp-call-hierarchy")

    public static let info = LumiPluginInfo(
        id: "LSPCallHierarchyEditor",
        displayName: LumiPluginLocalization.string("LSP Call Hierarchy", bundle: .module),
        description: LumiPluginLocalization.string("Shows incoming and outgoing call hierarchy for symbols.", bundle: .module),
        order: 25
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = CallHierarchyProvider(lspService: .shared)
        registry.registerCallHierarchyProvider(provider)
    }
}
