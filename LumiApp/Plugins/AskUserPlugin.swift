import AgentToolKit
import Foundation
import LumiCoreKit
import os
import PluginAskUser
import SwiftUI

/// AskUser 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginAskUser.AskUserPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
///
/// ## 功能
///
/// 提供 `ask_user` 工具，让 LLM 可以向用户提问并等待回答。
/// 支持是/否选择、多选项选择和自由文本输入。
actor AskUserPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "❓"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user")

    static let id = PluginAskUser.AskUserPlugin.id
    static let displayName: String = "询问用户"
    static let description: String = "提供 ask_user 工具，让 LLM 可以向用户提问并等待回答"
    static let iconName: String = "questionmark.circle.fill"
    static var category: PluginCategory { .agent }
    static var order: Int { PluginAskUser.AskUserPlugin.order }

    static let shared = AskUserPlugin()

    private init() {}

    // MARK: - Lifecycle

    nonisolated func onRegister() {}

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t) AskUserPlugin enabled")
        }
    }

    nonisolated func onDisable() {}

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginAskUser.AskUserTool()]
    }

    // MARK: - Message Renderers

    @MainActor
    func messageRenderers() -> [any SuperMessageRenderer] {
        [AskUserMessageRenderer()]
    }

    // MARK: - Hooks

    /// 监听用户回答通知，触发 resume
    func onLoad(context: PluginContext) async {
        // 转发给 package 插件
        await PluginAskUser.AskUserPlugin.shared.onLoad(context: context)

        // App 侧负责监听用户回答并触发 resume
        await MainActor.run {
            _ = NotificationCenter.default.addObserver(
                forName: .askUserDidRespond,
                object: nil,
                queue: .main
            ) { notification in
                guard let userInfo = notification.userInfo,
                      let toolCallId = userInfo["toolCallId"] as? String,
                      let answer = userInfo["answer"] as? String,
                      let conversationIdString = userInfo["conversationId"] as? String,
                      let conversationId = UUID(uuidString: conversationIdString) else {
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(Self.t) User answered ask_user: \(answer) for toolCallId: \(toolCallId)")
                }

                // 发送 resume 通知，触发新一轮 LLM 调用
                // 注意：用户回答已通过 AskUserPendingView 发送为 user 消息
                // 这里只需通知系统继续处理
                NotificationCenter.postResumeSendAfterToolPermission(conversationId: conversationId)
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t) AskUserPlugin loaded (App adapter)")
        }
    }
}

private struct AskUserMessageRenderer: SuperMessageRenderer {
    static let id = PluginAskUser.AskUserRenderer.id
    static let priority = PluginAskUser.AskUserRenderer.priority

    private let renderer = PluginAskUser.AskUserRenderer()

    func canRender(message: ChatMessage) -> Bool {
        renderer.canRender(message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        renderer.render(message: message, showRawMessage: showRawMessage)
    }
}
