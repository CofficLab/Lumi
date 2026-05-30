import SwiftUI
import AgentToolKit

/// 右侧栏中的待发送附件列表。
public struct ChatAttachmentSectionView: View {
    public var body: some View {
        if ChatAttachmentRuntime.pendingAttachments.isEmpty {
            EmptyView()
        } else {
            AttachmentPreviewView(
                attachments: ChatAttachmentRuntime.pendingAttachments,
                onRemove: { id in
                    ChatAttachmentRuntime.removeAttachment(id)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}
