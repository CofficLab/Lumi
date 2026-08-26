import ProviderConversation
import SwiftUI

/// 自动化级别 chip：显示当前会话的 automationLevel，点击弹出三档选择。
struct AutomationLevelToolbarView: View {
    let conversations: any ConversationManaging

    @State private var isPopoverPresented = false

    private var selectedLevel: AutomationLevel {
        if let id = conversations.selectedConversationID {
            return conversations.automationLevel(for: id)
        }
        return conversations.globalAutomationLevel
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedLevel.iconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(selectedLevel.levelCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedLevel.description)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            AutomationLevelPopover(selectedLevel: selectedLevel) { level in
                updateAutomationLevel(level)
                isPopoverPresented = false
            }
        }
    }

    private func updateAutomationLevel(_ level: AutomationLevel) {
        if let conversationID = conversations.selectedConversationID {
            conversations.setAutomationLevel(level, for: conversationID)
        }
        conversations.setGlobalAutomationLevel(level)
    }

    private var foregroundColor: Color {
        switch selectedLevel {
        case .chat: Color.cyan
        case .build: Color.orange
        case .autonomous: Color.green
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .chat: Color.cyan.opacity(0.22)
        case .build: Color.orange.opacity(0.22)
        case .autonomous: Color.green.opacity(0.22)
        }
    }
}

private struct AutomationLevelPopover: View {
    let selectedLevel: AutomationLevel
    let onSelect: (AutomationLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automation Level")
                .font(.system(size: 12, weight: .semibold))

            ForEach(AutomationLevel.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    AutomationLevelRow(level: level, isSelected: level == selectedLevel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct AutomationLevelRow: View {
    let level: AutomationLevel
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: level.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(level.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(level.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.primary)

                Text(level.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

enum ToolbarMetrics {
    static let chipIconSize: CGFloat = 10
    static let chipTextSize: CGFloat = 10
    static let chipTextWeight: Font.Weight = .medium
    static let chipSpacing: CGFloat = 3
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 3
    static let chipCornerRadius: CGFloat = 5
    static let iconWeight: Font.Weight = .medium
}
