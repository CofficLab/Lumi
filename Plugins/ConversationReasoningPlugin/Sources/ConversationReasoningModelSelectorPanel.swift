import LumiKernel
import LumiUI
import SwiftUI

struct ConversationReasoningModelSelectorPanel: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @State private var localEffort: LumiReasoningEffort = .defaultEffort

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    private var persistedEffort: LumiReasoningEffort {
        conversations?.reasoningEffort(for: selectedConversationID) ?? .defaultEffort
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 12, weight: .medium))
                Text("Reasoning")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(localEffort.levelCode)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                ForEach(LumiReasoningEffort.allCases) { effort in
                    Button {
                        select(effort)
                    } label: {
                        Image(systemName: effort.iconName)
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(effort == localEffort ? .white : theme.textSecondary)
                    .background(
                        effort == localEffort ? Color.accentColor : theme.surface.opacity(0.75),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .help("\(effort.displayName): \(effort.description)")
                }
            }

            Text(localEffort.description)
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.textTertiary.opacity(0.18), lineWidth: 1)
        )
        .onAppear(perform: syncFromConversation)
        .onChange(of: selectedConversationID) { _, _ in
            syncFromConversation()
        }
    }

    private func select(_ effort: LumiReasoningEffort) {
        localEffort = effort
        conversations?.setReasoningEffort(effort, for: selectedConversationID)
    }

    private func syncFromConversation() {
        localEffort = persistedEffort
    }
}
