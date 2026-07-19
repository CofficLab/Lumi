import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct AutomationLevelPicker: View {
    @LumiTheme private var theme
    @ObservedObject var chatService: ChatService

    @State private var isPopoverPresented = false

    private var selectedConversationID: UUID? {
        chatService.selectedConversationID
    }

    private var selectedLevel: LumiAutomationLevel {
        chatService.automationLevel(for: selectedConversationID)
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedLevel.iconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: ToolbarMetrics.iconWeight))
                Text(selectedLevel.levelCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(.red)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedLevel.description)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            AutomationLevelPopover(selectedLevel: selectedLevel) { level in
                chatService.setAutomationLevel(level, for: selectedConversationID)
                isPopoverPresented = false
            }
        }
    }
}

private struct AutomationLevelPopover: View {
    @LumiTheme private var theme

    let selectedLevel: LumiAutomationLevel
    let onSelect: (LumiAutomationLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: LumiPluginLocalization.string("自动化程度", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            ForEach(LumiAutomationLevel.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: level.iconName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(level == selectedLevel ? .red : theme.textSecondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(level.levelCode)
                                    .font(.appCaptionEmphasized)
                                Text(level.displayName)
                                    .font(.appCaption)
                            }
                            .foregroundColor(theme.textPrimary)

                            Text(level.description)
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer(minLength: 8)

                        if level == selectedLevel {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(level == selectedLevel ? Color.red.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}
