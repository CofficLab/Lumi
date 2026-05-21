import os
import SwiftUI

/// 自动批准开关插件
actor AgentAutoApprovePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-auto-approve")

    static let id = "AgentAutoApprovePlugin"
    static let displayName = String(localized: "Auto-Approve Toggle", table: "AgentAutoApprovePlugin")
    static let description = String(localized: "Auto-approve toggle in chat header", table: "AgentAutoApprovePlugin")
    static let iconName = "checkmark.circle"
    static var order: Int { 82 }

    /// 核心安全功能，禁止用户配置
    static var isConfigurable: Bool { false }

    static let enable: Bool = true

    static let shared = AgentAutoApprovePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "auto-approve-toggle",
                title: String(localized: "Auto-Approve Toggle", table: "AgentAutoApprovePlugin"),
                systemImage: "checkmark.circle",
                priority: 20
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        guard itemId == "auto-approve-toggle" else { return nil }
        return AnyView(AutoApproveToggle())
    }
}

// MARK: - Preview

#Preview("Auto Approve Plugin") {
    AutoApproveToggle()
        .padding()
        .inRootView()
}
