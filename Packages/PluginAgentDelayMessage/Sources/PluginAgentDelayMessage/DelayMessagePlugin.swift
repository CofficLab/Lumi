import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
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
/// - `DelayMessageTool`：接收 message + seconds，使用工具执行上下文中的会话 ID 延时后入队
///
/// ## 数据流
///
/// ```
/// EnvironmentObject (conversationVM / messageQueueVM)
///         ↓  (DelayMessageOverlay 同步)
/// DelayMessageState (@MainActor 单例)
///         ↓  (工具入队消息)
/// DelayMessageTool
/// ```
public actor DelayMessagePlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.delay-message")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "⏳"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "DelayMessage"
    public static let displayName: String = String(localized: "Delay Message", table: "DelayMessage")
    public static let description: String = String(localized: "Schedule delayed messages to resume conversations automatically.", table: "DelayMessage")
    public static let iconName: String = "clock.badge"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 98 }

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = DelayMessagePlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)📝 已注册")
            }
        }
    }

    public nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)✅ 已启用")
            }
        }
    }

    public nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)⛔️ 已禁用")
            }
        }
    }

    // MARK: - Views

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        nil
    }

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [DelayMessageTool()]
    }
}
