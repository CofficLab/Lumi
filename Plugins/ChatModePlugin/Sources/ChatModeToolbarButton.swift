import LumiUI
import LumiCoreKit
import SwiftUI

public struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPopoverPresented = false

    public init() {}

    public var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: llmVM.chatMode.iconName)
                    .font(.system(size: 13))
                Text(llmVM.chatMode.levelCode)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(String(localized: "Chat Mode", bundle: .module))
        .accessibilityHint(String(localized: "Chat Mode Hint", bundle: .module))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ChatModeLevelPopover(
                selectedMode: llmVM.chatMode,
                onSelect: selectMode
            )
        }
        .onAppear(perform: restoreConversationPreference)
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            restoreConversationPreference()
        }
    }

    private func selectMode(_ mode: ChatMode) {
        withAnimation {
            llmVM.setChatMode(mode)
        }
        isPopoverPresented = false
    }

    private func restoreConversationPreference() {
        guard let preference = conversationVM.getChatModePreference() else { return }
        llmVM.setChatMode(preference)
    }

    private var foregroundColor: Color {
        switch llmVM.chatMode {
        case .chat: return .orange
        case .build: return theme.textSecondary
        case .autonomous: return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var helpText: String {
        llmVM.chatMode.localizedHelpText
    }
}

private struct ChatModeLevelPopover: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let selectedMode: ChatMode
    let onSelect: (ChatMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Autonomy Level", bundle: .module))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)

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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let mode: ChatMode
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.iconName)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(isSelected ? theme.primary : modeTint)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(mode.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(mode.localizedDisplayName)
                        .font(.system(size: 12, weight: .medium))
                }

                Text(mode.localizedDescription)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 5) {
                    ForEach(mode.localizedCapabilityLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(theme.textSecondary.opacity(0.10))
                            )
                    }
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
        }
        .foregroundColor(theme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var modeTint: Color {
        switch mode {
        case .chat: return .orange
        case .build: return theme.textSecondary
        case .autonomous: return .red
        }
    }
}

private extension ChatMode {
    var localizedDisplayName: String {
        switch self {
        case .chat:
            return String(localized: "Chat Mode Name", bundle: .module)
        case .build:
            return String(localized: "Build Mode Name", bundle: .module)
        case .autonomous:
            return String(localized: "Autonomous Mode Name", bundle: .module)
        }
    }

    var localizedDescription: String {
        switch self {
        case .chat:
            return String(localized: "Chat Mode Description", bundle: .module)
        case .build:
            return String(localized: "Build Mode Description", bundle: .module)
        case .autonomous:
            return String(localized: "Autonomous Mode Description", bundle: .module)
        }
    }

    var localizedHelpText: String {
        switch self {
        case .chat:
            return String(localized: "Chat Mode Help", bundle: .module)
        case .build:
            return String(localized: "Build Mode Help", bundle: .module)
        case .autonomous:
            return String(localized: "Autonomous Mode Help", bundle: .module)
        }
    }

    var localizedCapabilityLabels: [String] {
        switch self {
        case .chat:
            return [
                String(localized: "Tools Off", bundle: .module),
                String(localized: "No Code Changes", bundle: .module)
            ]
        case .build:
            return [
                String(localized: "Tools On", bundle: .module),
                String(localized: "Confirm Risk", bundle: .module)
            ]
        case .autonomous:
            return [
                String(localized: "Tools On", bundle: .module),
                String(localized: "Auto Approve Risk", bundle: .module)
            ]
        }
    }
}
