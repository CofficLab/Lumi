import SwiftUI
import AgentToolKit
import LumiCoreKit

/// 右侧栏中的待发送附件列表。
public struct ChatAttachmentSectionView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM

    public var body: some View {
        if conversationVM.pendingAttachments.isEmpty {
            EmptyView()
        } else {
            AttachmentPreviewView(
                attachments: conversationVM.pendingAttachments,
                onRemove: { id in
                    conversationVM.removeAttachment(id: id)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}
