import MagicKit
import SwiftUI
import os

/// Agent Turn Notification Plugin
///
/// 在 AgentTurnService 一轮循环结束时发出 macOS 系统通知，
/// 让用户在焦点离开应用时也能知道 Agent 完成了工作。
actor AgentTurnNotificationPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.turn-notification")

    nonisolated static let emoji = "🔔"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "AgentTurnNotification"
    static let displayName: String = String(localized: "Turn Notification", table: "AgentTurnNotification")
    static let description: String = String(
        localized: "Send a system notification when an Agent turn finishes.", table: "AgentTurnNotification")
    static let iconName: String = "bell.badge"
    static let isConfigurable: Bool = false
    static var order: Int { 99 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = AgentTurnNotificationPlugin()

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ AgentTurnNotificationPlugin 初始化完成")
        }
    }

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 AgentTurnNotificationPlugin 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ AgentTurnNotificationPlugin 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ AgentTurnNotificationPlugin 已禁用")
        }
    }

    // MARK: - Root View

    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AgentTurnNotificationOverlay(content: content()))
    }
}
