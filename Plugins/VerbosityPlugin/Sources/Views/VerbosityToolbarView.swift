import LumiKernel
import LumiUI
import SwiftUI

struct VerbosityToolbarView: View {
    @ObservedObject var kernel: LumiKernel
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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

    private var foregroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan
        case .standard:
            theme.textSecondary
        case .detailed:
            .purple
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan.opacity(0.22)
        case .standard:
            theme.textSecondary.opacity(0.14)
        case .detailed:
            Color.purple.opacity(0.22)
        }
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
                conversations?.setVerbosity(level, for: selectedConversationID)
                isPopoverPresented = false
            }
        }
    }
}
