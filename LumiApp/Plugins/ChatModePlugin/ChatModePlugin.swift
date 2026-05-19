import MagicKit
import SwiftUI
import os

/// 聊天模式切换插件
///
/// 在右侧栏底部工具栏注入 Chat/Build 模式切换按钮。
/// 通过 `AppLLMVM` 读写当前模式状态。
actor ChatModePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-mode")

    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = false
    static let id = "ChatMode"
    static let displayName = String(localized: "Chat Mode", table: "AgentChat")
    static let description = String(localized: "Switch between Chat and Build modes", table: "AgentChat")
    static let iconName = "arrow.triangle.2.circlepath"
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
                title: String(localized: "Chat Mode", table: "AgentChat"),
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

// MARK: - Toolbar Button View

/// 模式切换工具栏按钮
///
/// 显示当前模式图标和名称，点击切换 Chat / Build。
private struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        Button(action: {
            withAnimation {
                llmVM.setChatMode(llmVM.chatMode == .chat ? .build : .chat)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: llmVM.chatMode.iconName)
                    .font(.system(size: 13))
                Text(llmVM.chatMode.displayName)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(String(localized: "Chat Mode", table: "AgentChat"))
        .accessibilityHint(String(localized: "Chat Mode Hint", table: "AgentChat"))
    }

    private var foregroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange
        case .build:
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
    }

    private var backgroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange.opacity(0.1)
        case .build:
            return themeVM.activeAppTheme.workspaceTextColor().opacity(0.06)
        }
    }

    private var helpText: String {
        switch llmVM.chatMode {
        case .chat:
            return String(localized: "Chat Mode Description", table: "AgentChat")
        case .build:
            return String(localized: "Build Mode Description", table: "AgentChat")
        }
    }
}
