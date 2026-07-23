import LumiKernel
import SwiftUI

struct VerbosityToolbarView: View {
    @ObservedObject var kernel: LumiKernel

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    private var selectedLevel: LumiResponseVerbosity {
        conversations?.verbosity(for: selectedConversationID) ?? .defaultVerbosity
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
            VerbosityPopover(selectedLevel: selectedLevel) { level in
                conversations?.setVerbosity(level, for: selectedConversationID)
                isPopoverPresented = false
            }
        }
    }

    private var foregroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan
        case .standard:
            Color.secondary
        case .detailed:
            .purple
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan.opacity(0.1)
        case .standard:
            Color.primary.opacity(0.06)
        case .detailed:
            Color.purple.opacity(0.12)
        }
    }
}

private struct VerbosityPopover: View {
    let selectedLevel: LumiResponseVerbosity
    let onSelect: (LumiResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verbosity Level")
                .font(.system(size: 12, weight: .semibold))

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
    let level: LumiResponseVerbosity
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
