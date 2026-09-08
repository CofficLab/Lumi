import Combine
import ProviderConversation
import ProviderToast
import SwiftUI

/// 详细度 chip：显示当前会话的 verbosity，点击弹出三档选择。
struct VerbosityToolbarView: View {
    @ObservedObject private var conversationObservation: ConversationManagerObservationBox
    let toast: (any ToastProviding)?

    @State private var isPopoverPresented = false

    init(observation: ConversationManagerObservationBox, toast: (any ToastProviding)? = nil) {
        self.conversationObservation = observation
        self.toast = toast
    }

    private var capability: any ConversationVerbosityCapability {
        conversationObservation.capability
    }

    private var selectedVerbosity: ResponseVerbosity {
        if let id = capability.selectedConversationID {
            return capability.verbosity(for: id)
        }
        return capability.globalVerbosity
    }

    var body: some View {
        let _ = conversationObservation.revision
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
                capability.setGlobalVerbosity(level)
                if let conversationID = capability.selectedConversationID {
                    Task { @MainActor in
                        await capability.setVerbosityAndWait(level, for: conversationID)
                    }
                }
                ConversationVerbosityToast.show(
                    toast,
                    title: LumiPluginLocalization.string("Response Detail", bundle: .module),
                    detail: level.levelCode,
                )
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
