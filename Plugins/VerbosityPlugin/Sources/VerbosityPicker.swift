import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct VerbosityPicker: View {
    @LumiTheme private var theme
    @ObservedObject var chatService: ChatService

    @State private var isPopoverPresented = false

    private var selectedConversationID: UUID? {
        chatService.selectedConversationID
    }

    private var selectedLevel: LumiResponseVerbosity {
        chatService.verbosity(for: selectedConversationID)
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
            VerbosityPopover(selectedLevel: selectedLevel) { level in
                chatService.setVerbosity(level, for: selectedConversationID)
                isPopoverPresented = false
            }
        }
    }

    private var foregroundColor: Color {
        switch selectedLevel {
        case .brief:
            theme.info
        case .standard:
            theme.textSecondary
        case .detailed:
            .purple
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .brief:
            theme.info.opacity(0.1)
        case .standard:
            theme.textPrimary.opacity(0.06)
        case .detailed:
            Color.purple.opacity(0.12)
        }
    }
}

private struct VerbosityPopover: View {
    @LumiTheme private var theme

    let selectedLevel: LumiResponseVerbosity
    let onSelect: (LumiResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: LumiPluginLocalization.string("详细级别", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            ForEach(LumiResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityRow(level: level, isSelected: level == selectedLevel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct VerbosityRow: View {
    @LumiTheme private var theme

    let level: LumiResponseVerbosity
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: level.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
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

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? theme.primary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
