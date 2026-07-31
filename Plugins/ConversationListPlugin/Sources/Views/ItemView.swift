import LumiKernel
import LumiUI
import SwiftUI

/// 会话项视图
public struct ItemView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let conversation: LumiConversationSummary
    public let svc: any ConversationManaging
    public let kernel: LumiKernel

    @State private var isSelected: Bool = false

    public init(conversation: LumiConversationSummary, svc: any ConversationManaging, kernel: LumiKernel) {
        self.conversation = conversation
        self.svc = svc
        self.kernel = kernel
    }

    public var body: some View {
        AppListRow(isSelected: isSelected) {
            content
        }
        .onAppear {
            isSelected = svc.selectedConversationID == conversation.id
        }
        .onLumiConversationsDidChange {
            isSelected = svc.selectedConversationID == conversation.id
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .padding(3)

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
        .contentShape(Rectangle())
        .onTapGesture {
            svc.selectConversation(id: conversation.id)
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
