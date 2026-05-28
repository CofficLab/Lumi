import AgentToolKit
import SwiftUI
import SuperLogKit
import LumiCoreKit
import os

/// 用户询问插件
///
/// 提供 ask_user 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
///
/// ## 功能
///
/// - **AskUserTool**: LLM 调用的工具，用于提问
/// - **AskUserRenderer**: 消息渲染器，显示选择界面
///
/// ## 使用示例
///
/// LLM 调用:
/// ```json
/// {
///   "name": "ask_user",
///   "arguments": {
///     "question": "是否继续执行此操作？",
///     "options": ["是", "否"]
///   }
/// }
/// ```
///
/// 用户点击"是"后，系统自动发送一条 user 消息 "是"，LLM 下一轮收到继续处理。
public actor AskUserPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "❓"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user")

    public static let shared = AskUserPlugin()
    public static let id = "plugin-ask-user"
    public static let displayName = String(localized: "用户询问插件", table: "AskUser")
    public static let description = String(localized: "提供 ask_user 工具，让 LLM 可以向用户提问并等待回答", table: "AskUser")
    public static let iconName = "questionmark.circle.fill"
    public static var category: PluginCategory { .general }
    public static var order: Int { 100 }

    public init() {}

    // MARK: - Tools

    @MainActor
    public func tools() -> [any SuperAgentTool] {
        [AskUserTool()]
    }

    // MARK: - Message Renderers

    @MainActor
    public func messageRenderers() -> [any SuperMessageRenderer] {
        [AskUserRenderer()]
    }

    // MARK: - Hooks

    /// Package 侧插件加载时不处理通知
    /// App 侧适配器负责监听用户回答并触发 resume
    public func onLoad(context: PluginContext) async {
        // Package 侧只提供工具和渲染器
        // App 侧适配器负责监听 askUserDidRespond 通知并触发 resume
    }
}