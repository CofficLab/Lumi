import SwiftUI

/// 模式切换工具栏按钮
///
/// 显示当前模式图标和名称，点击切换 Chat / Build。
struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        Button(action: {
            let newMode: ChatMode = llmVM.chatMode == .chat ? .build : .chat
            withAnimation {
                llmVM.setChatMode(newMode)
            }
            // 直接保存到当前对话的聊天模式偏好
            conversationVM.saveChatModePreference(newMode)
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

    // MARK: - 计算属性

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
