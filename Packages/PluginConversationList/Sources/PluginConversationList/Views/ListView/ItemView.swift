import LumiUI
import ProviderConversation
import ProviderConversationState
import SwiftUI

/// 会话项视图
struct ItemView: View {
    @LumiTheme private var theme: any LumiUITheme

    let conversation: ConversationSummary
    let conversationState: ConversationStateSnapshot?
    let isSelected: Bool
    let needsAttention: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: {
            onSelect()
        }) {
            content
        }
        // Attach the menu to the row itself. Attaching it to `content` puts it
        // inside AppListRow's Button label, and the button consumes the
        // right-click before SwiftUI can present the menu on macOS.
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title ?? "对话")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let providerID = conversation.providerID {
                    HStack(spacing: 4) {
                        Text(providerID)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)

                        if let modelName = conversation.modelName, !modelName.isEmpty {
                            Text("·")
                                .foregroundColor(theme.textTertiary)
                            Text(modelName)
                                .font(.footnote)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                }

                HStack(spacing: 4) {
                    if let projectPath = conversation.projectPath {
                        Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text("·")
                            .foregroundColor(theme.textTertiary)
                    }

                    Text(conversation.lastMessageAt.relativeTime)
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)

                    if let automationLevel = conversation.automationLevel {
                        Text("·")
                            .foregroundColor(theme.textTertiary)

                        Label(automationLevel.displayName, systemImage: automationLevel.iconName)
                            .labelStyle(.titleAndIcon)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .overlay(alignment: .topTrailing) {
            statusIndicator
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch conversationState?.agentLoopState {
        case .running:
            pulsingAttentionDot
        case .suspended:
            stateIcon("pause.circle.fill", color: .orange)
        case .failed:
            stateIcon("exclamationmark.triangle.fill", color: .red)
        case .completed, .cancelled, .idle, nil:
            if needsAttention { attentionDot }
        }
    }

    private func stateIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.top, 3)
            .padding(.trailing, 2)
            .allowsHitTesting(false)
    }

    private var attentionDot: some View {
        dotCore
            .padding(.top, 3)
            .padding(.trailing, 2)
            .allowsHitTesting(false)
    }

    private var pulsingAttentionDot: some View {
        ZStack {
            dotCore

            Circle()
                .stroke(Color.accentColor.opacity(0.75), lineWidth: 1)
                .frame(width: 6, height: 6)
                .phaseAnimator([false, true]) { ring, phase in
                    ring
                        .scaleEffect(phase ? 3.2 : 1)
                        .opacity(phase ? 0 : 0.75)
                } animation: { _ in
                    .easeOut(duration: 1.1)
                }
        }
        .frame(width: 22, height: 22)
        .padding(.top, -5)
        .padding(.trailing, -6)
        .allowsHitTesting(false)
    }

    private var dotCore: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)
    }
}
