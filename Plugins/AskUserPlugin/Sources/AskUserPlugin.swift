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
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let emoji = "❓"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user")

    public static let shared = AskUserPlugin()
    public static let id = "plugin-ask-user"
    public static let displayName = String(localized: "用户询问插件", bundle: .module)
    public static let description = String(localized: "提供 ask_user 工具，让 LLM 可以向用户提问并等待回答", bundle: .module)
    public static let iconName = "questionmark.circle.fill"
    public static var category: PluginCategory { .general }
    public static var order: Int { 100 }

    public init() {}

    // MARK: - Runtime

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        AskUserBridge.shared.resumeHandler = { conversationId, toolCallId, answer in
            context.resumeToolCall(conversationId, toolCallId, answer)
        }
    }

    // MARK: - Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [AskUserTool()]
    }

    // MARK: - Message Renderers

    @MainActor
    public func messageRenderers() -> [any SuperMessageRenderer] {
        [AskUserRenderer()]
    }


}