import SwiftUI

/// 右侧栏中的待发送附件列表。
struct ChatAttachmentSectionView: View {
    @EnvironmentObject private var attachmentsVM: WindowAttachmentsVM

    var body: some View {
        if attachmentsVM.pendingAttachments.isEmpty {
            EmptyView()
        } else {
            AttachmentPreviewView(
                attachments: attachmentsVM.pendingAttachments,
                onRemove: { id in
                    attachmentsVM.removeAttachment(id: id)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}
