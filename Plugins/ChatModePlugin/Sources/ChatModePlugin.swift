import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 聊天模式切换插件
///
/// 在右侧栏底部工具栏注入 Chat/Build 模式切换按钮。
/// 通过 `AppLLMVM` 读写当前模式状态。
public actor ChatModePlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-mode")

    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = true
    public static let id = "ChatMode"
    public static let displayName = String(localized: "Chat Mode", bundle: .module)
    public static let description = String(localized: "Switch between Chat and Build modes", bundle: .module)
    public static let iconName = "arrow.triangle.2.circlepath"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 83 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ChatModePlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat else { return [] }
        return [
            SidebarToolbarItem(
                id: "chat-mode-toggle",
                title: String(localized: "Chat Mode", bundle: .module),
                systemImage: "arrow.triangle.2.circlepath",
                priority: 10
            )
        ]
    }

    @MainActor public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "chat-mode-toggle" else { return nil }
        return AnyView(ChatModeToolbarButton())
    }
}
