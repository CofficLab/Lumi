import LumiKernel
import LumiUI
import SwiftUI

/// 会话项视图
public struct ItemView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let conversation: LumiConversationSummary
    public let svc: any ConversationManaging
    @ObservedObject private var kernel: LumiKernel
    @ObservedObject private var attentionStore: ConversationAttentionStore

    @State private var isSelected: Bool = false

    public init(
        conversation: LumiConversationSummary,
        svc: any ConversationManaging,
        kernel: LumiKernel,
        attentionStore: ConversationAttentionStore
    ) {
        self.conversation = conversation
        self.svc = svc
        self.kernel = kernel
        self.attentionStore = attentionStore
    }

    public var body: some View {
        AppListRow(isSelected: isSelected, action: {
            self.isSelected = true
            svc.selectConversation(id: conversation.id)
            attentionStore.markRead(conversationID: conversation.id)
        }) {
            content
        }
        .onAppear {
            isSelected = svc.selectedConversationID == conversation.id
        }
        .onLumiConversationsDidChange {
            isSelected = svc.selectedConversationID == conversation.id
            if isSelected {
                attentionStore.markRead(conversationID: conversation.id)
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
                
                HStack {
                    Text(conversation.updatedAt.relativeTime)
                        .font(.footnote)
                        .foregroundColor(theme.textTertiary)
                    
                    Spacer()
                    
                    if let projectPath = conversation.projectPath {
                        Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                            .font(.footnote)
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer()
        }
        .overlay(alignment: .topTrailing) {
            if !isSelected {
                if isActive {
                    pulsingAttentionDot
                } else if attentionStore.needsAttention(for: conversation.id) {
                    attentionDot
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                svc.deleteConversation(id: conversation.id)
            } label: {
                Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
            }
        }
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

    private var isActive: Bool {
        kernel.agentTurnManager?.isRunning(for: conversation.id) == true
    }

}
