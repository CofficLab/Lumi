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
        .onReceive(NotificationCenter.default.publisher(for: .lumiConversationsDidChange)) { _ in
            isSelected = svc.selectedConversationID == conversation.id
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .padding(3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if conversation.order == 0 {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(theme.primary)
                    }

                    Text(kernel.uiTitle(for: conversation.id))
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(conversation.updatedAt.relativeTime)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            svc.selectConversation(id: conversation.id)
        }
        .contextMenu {
            Button {
                let newOrder = conversation.order == 0 ? LumiConversationSummary.defaultOrder : 0
                svc.setConversationOrder(newOrder, for: conversation.id)
            } label: {
                Label(
                    conversation.order == 0 ? "Unpin" : "Pin",
                    systemImage: conversation.order == 0 ? "pin.slash" : "pin"
                )
            }

            Button(role: .destructive) {
                svc.deleteConversation(id: conversation.id)
            } label: {
                Label(LumiPluginLocalization.string("Delete", bundle: .module), systemImage: "trash")
            }
        }
    }

}
