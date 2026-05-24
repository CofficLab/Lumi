import SwiftUI
import os

/// 聊天模式切换插件
///
/// 在右侧栏底部工具栏注入 Chat/Build 模式切换按钮。
/// 通过 `AppLLMVM` 读写当前模式状态。
actor ChatModePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-mode")

    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = true
    static let id = "ChatMode"
    static let displayName = String(localized: "Chat Mode", table: "ChatMode")
    static let description = String(localized: "Switch between Chat and Build modes", table: "ChatMode")
    static let iconName = "arrow.triangle.2.circlepath"
    static var category: PluginCategory { .agent }
    static var order: Int { 83 }
    nonisolated static let enable: Bool = true
    static let shared = ChatModePlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "chat-mode-toggle",
                title: String(localized: "Chat Mode", table: "ChatMode"),
                systemImage: "arrow.triangle.2.circlepath",
                priority: 10
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        guard itemId == "chat-mode-toggle" else { return nil }
        return AnyView(ChatModeToolbarButton())
    }
}
