import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// Agent Turn Notification Plugin
///
/// 在 AgentTurnService 一轮循环结束时发出 macOS 系统通知，
/// 让用户在焦点离开应用时也能知道 Agent 完成了工作。
public actor AgentTurnNotificationPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.turn-notification")

    public nonisolated static let emoji = "🔔"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "AgentTurnNotification"
    public static let displayName: String = String(localized: "Turn Notification", table: "AgentTurnNotification")
    public static let description: String = String(
        localized: "Send a system notification when an Agent turn finishes.", table: "AgentTurnNotification")
    public static let iconName: String = "bell.badge"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 99 }

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = AgentTurnNotificationPlugin()

    public init() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ AgentTurnNotificationPlugin 初始化完成")
            }
        }
    }

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)📝 AgentTurnNotificationPlugin 已注册")
            }
        }
    }

    public nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ AgentTurnNotificationPlugin 已启用")
            }
        }
    }

    public nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)⛔️ AgentTurnNotificationPlugin 已禁用")
            }
        }
    }

    // MARK: - Root View

    @MainActor public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AgentTurnNotificationOverlay(content: content()))
    }
}
