import ProviderConversation
import SwiftUI

/// 详细度 chip：显示当前会话的 verbosity，点击弹出三档选择。
struct VerbosityToolbarView: View {
    let conversations: any ConversationManaging

    @State private var isPopoverPresented = false

    private var selectedVerbosity: ResponseVerbosity {
        if let id = conversations.selectedConversationID {
            return conversations.verbosity(for: id)
        }
        return conversations.globalVerbosity
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedVerbosity.iconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(selectedVerbosity.levelCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedVerbosity.description)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VerbosityPopover(selected: selectedVerbosity) { level in
                if let conversationID = conversations.selectedConversationID {
                    conversations.setVerbosity(level, for: conversationID)
                }
                conversations.setGlobalVerbosity(level)
                isPopoverPresented = false
            }
        }
    }
}

private struct VerbosityPopover: View {
    let selected: ResponseVerbosity
    let onSelect: (ResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LumiPluginLocalization.string("Response Detail", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            ForEach(ResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityRow(level: level, isSelected: level == selected)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct VerbosityRow: View {
    let level: ResponseVerbosity
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
