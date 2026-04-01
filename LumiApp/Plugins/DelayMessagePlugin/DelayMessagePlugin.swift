import Foundation
import MagicKit
import SwiftUI
import os

/// 延时消息插件
///
/// 提供 LLM 在未来某个时刻自动恢复对话的能力。
/// 核心思想：延时结束后向消息队列注入一条用户消息，等价于用户自己输入了一句话。
///
/// ## 架构
///
/// - `DelayMessageState`（@MainActor 单例）：存储从 Environment 同步来的 VM 引用
/// - `DelayMessagePlugin`（Actor）：插件主体，提供 `addRootView` 和工具
/// - `DelayMessageOverlay`（View）：通过 `addRootView` 挂载，用 `@EnvironmentObject` 监听 VM 变化
/// - `GetCurrentConversationTool`：返回状态中缓存的当前会话 ID
/// - `DelayMessageTool`：接收 conversationId + message + seconds，延时后入队
///
/// ## 数据流
///
/// ```
/// EnvironmentObject (conversationVM / messageQueueVM)
///         ↓  (DelayMessageOverlay 同步)
/// DelayMessageState (@MainActor 单例)
///         ↓  (工具读取)
/// DelayMessageTool / GetCurrentConversationTool
/// ```
actor DelayMessagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.delay-message")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "⏳"
    nonisolated static let enable = true
    nonisolated static let verbose = false

    static let id: String = "DelayMessage"
    static let displayName: String = String(localized: "Delay Message", table: "DelayMessage")
    static let description: String = String(localized: "Schedule delayed messages to resume conversations automatically.", table: "DelayMessage")
    static let iconName: String = "clock.badge"
    static let isConfigurable: Bool = false
    static var order: Int { 98 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DelayMessagePlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(self.t)📝 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(self.t)✅ 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(self.t)⛔️ 已禁用")
        }
    }

    // MARK: - Views

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(DelayMessageOverlay(content: content()))
    }

    // MARK: - Agent Tools

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(DelayMessageToolFactory())]
    }
}

// MARK: - Tool Factory

@MainActor
private struct DelayMessageToolFactory: AgentToolFactory {
    let id: String = "delay.message.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            GetCurrentConversationTool(),
            DelayMessageTool(),
        ]
    }
}