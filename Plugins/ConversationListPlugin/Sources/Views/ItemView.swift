import LumiKernel
import LumiUI
import SwiftUI

/// 会话项视图
public struct ItemView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let conversation: LumiConversationSummary
    public let svc: any ConversationManaging
    public let kernel: LumiKernel
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
            if attentionStore.needsAttention(for: conversation.id) && !isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 3)
                    .padding(.trailing, 2)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Needs attention")
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

}
