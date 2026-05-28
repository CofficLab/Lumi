import SwiftUI

/// 模式切换工具栏按钮
///
/// 显示当前自主等级，点击弹出等级说明和选择器。
struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var isPopoverPresented = false

    var body: some View {
        Button(action: {
            isPopoverPresented.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: llmVM.chatMode.iconName)
                    .font(.system(size: 13))
                Text(llmVM.chatMode.levelCode)
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
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ChatModeLevelPopover(
                selectedMode: llmVM.chatMode,
                onSelect: selectMode
            )
            .environmentObject(themeVM)
        }
    }

    private func selectMode(_ mode: ChatMode) {
        withAnimation {
            llmVM.setChatMode(mode)
        }
        conversationVM.saveChatModePreference(mode)
        isPopoverPresented = false
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
            return "A1 对话：只聊天，不执行操作"
        case .build:
            return "A2 构建：可执行工具，高风险需确认"
        case .autonomous:
            return "A3 自主：可执行工具，高风险自动批准"
        }
    }
}

private struct ChatModeLevelPopover: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let selectedMode: ChatMode
    let onSelect: (ChatMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自主级别")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())

            ForEach(ChatMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    ChatModeLevelRow(
                        mode: mode,
                        isSelected: mode == selectedMode
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 290)
    }
}

private struct ChatModeLevelRow: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let mode: ChatMode
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.iconName)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(isSelected ? themeVM.activeChromeTheme.accentColors().primary : modeTint)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mode.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(mode.description)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeVM.activeChromeTheme.accentColors().primary)
            }
        }
        .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? themeVM.activeChromeTheme.accentColors().primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var modeTint: Color {
        switch mode {
        case .chat:
            return Color.orange
        case .build:
            return themeVM.activeChromeTheme.workspaceSecondaryTextColor()
        case .autonomous:
            return Color.red
        }
    }
}
