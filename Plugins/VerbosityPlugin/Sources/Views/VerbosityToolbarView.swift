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
            .foregroundColor(selectedLevel.foregroundColor)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(selectedLevel.backgroundColor, in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
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
