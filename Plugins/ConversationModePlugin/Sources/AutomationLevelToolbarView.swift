import LumiKernel
import SwiftUI

struct AutomationLevelToolbarView: View {
    let kernel: LumiKernel

    // automationLevel 随当前会话切换变化。用事件 + @State 缓存，不挂 kernel 全局总线。
    @State private var selectedConversationID: UUID?
    @State private var selectedLevel: LumiAutomationLevel = .build

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    @State private var isPopoverPresented = false

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
        .task { refreshState() }
        .onLumiSelectedConversationDidChange { refreshState() }
    }

    private func refreshState() {
        let id = conversations?.selectedConversationID
        selectedConversationID = id
        guard let conversations else {
            selectedLevel = .build
            return
        }
        if let id {
            selectedLevel = conversations.automationLevel(for: id)
        } else {
            selectedLevel = conversations.globalAutomationLevel
        }
    }

    private func updateAutomationLevel(_ level: LumiAutomationLevel) {
        guard let conversations else { return }
        if let conversationID = conversations.selectedConversationID {
            conversations.setAutomationLevel(level, for: conversationID)
        }
        conversations.setGlobalAutomationLevel(level)
        selectedLevel = level
    }

    private var foregroundColor: Color {
        switch selectedLevel {
        case .chat:
            Color.cyan
        case .build:
            Color.orange
        case .autonomous:
            Color.green
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .chat:
            Color.cyan.opacity(0.22)
        case .build:
            Color.orange.opacity(0.22)
        case .autonomous:
            Color.green.opacity(0.22)
        }
    }
}

private struct AutomationLevelPopover: View {
    let selectedLevel: LumiAutomationLevel
    let onSelect: (LumiAutomationLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LumiPluginLocalization.string("Automation Level", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            ForEach(LumiAutomationLevel.allCases) { level in
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
    let level: LumiAutomationLevel
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
