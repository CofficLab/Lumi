import SwiftUI

/// 模式切换工具栏按钮
///
/// 显示当前模式图标和名称，点击循环切换 Chat / Build / Autonomous。
struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 模式循环顺序
    private static let modeOrder: [ChatMode] = [.chat, .build, .autonomous]

    var body: some View {
        Button(action: {
            let currentIndex = Self.modeOrder.firstIndex(of: llmVM.chatMode) ?? 0
            let nextIndex = (currentIndex + 1) % Self.modeOrder.count
            let newMode = Self.modeOrder[nextIndex]
            withAnimation {
                llmVM.setChatMode(newMode)
            }
            // 直接保存到当前对话的聊天模式偏好
            conversationVM.saveChatModePreference(newMode)
            alert_info(
                String(localized: "Switched to \(newMode.displayName) Mode", table: "ChatMode"),
                subtitle: newMode.description
            )
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
        .accessibilityLabel(String(localized: "Chat Mode", table: "ChatMode"))
        .accessibilityHint(String(localized: "Chat Mode Hint", table: "ChatMode"))
    }

    // MARK: - 计算属性

    private var foregroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange
        case .build:
            return themeVM.activeChromeTheme.workspaceSecondaryTextColor()
        case .autonomous:
            return Color.red
        }
    }

    private var backgroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange.opacity(0.1)
        case .build:
            return themeVM.activeChromeTheme.workspaceTextColor().opacity(0.06)
        case .autonomous:
            return Color.red.opacity(0.1)
        }
    }

    private var helpText: String {
        switch llmVM.chatMode {
        case .chat:
            return String(localized: "Chat Mode Description", table: "ChatMode")
        case .build:
            return String(localized: "Build Mode Description", table: "ChatMode")
        case .autonomous:
            return String(localized: "Autonomous Mode Description", table: "ChatMode")
        }
    }
}
