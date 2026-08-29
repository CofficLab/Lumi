import AppKit
import Combine
import LumiUI
import ProviderMessage
import ProviderMessageSender
import SwiftUI

/// 聊天输入框上方的待发送图片预览。
///
/// 发送器通过 existential provider 注入，因此使用 objectWillChange + revision
/// 驱动 SwiftUI 重建，避免把具体的发送器实现泄漏到输入插件中。
struct AttachmentPreviewView: View {
    @LumiTheme private var theme

    let sender: (any MessageSendingProviding)?
    @State private var revision = 0

    private var attachments: [UserImageAttachment] {
        sender?.pendingImageAttachments ?? []
    }

    var body: some View {
        let _ = revision

        Group {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            AttachmentThumbnail(
                                attachment: attachment,
                                onRemove: {
                                    sender?.removeImageAttachment(id: attachment.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(theme.textPrimary.opacity(0.04))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onReceive(sender?.objectWillChange ?? ObservableObjectPublisher()) { _ in
            DispatchQueue.main.async {
                revision &+= 1
            }
        }
    }
}

private struct AttachmentThumbnail: View {
    let attachment: UserImageAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove image")
            .offset(x: 6, y: -6)
        }
        .help(attachment.fileName ?? attachment.mimeType)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = decodedImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray)
                }
        }
    }

    private var decodedImage: NSImage? {
        guard let data = Data(base64Encoded: attachment.base64Data) else {
            return nil
        }
        return NSImage(data: data)
    }
}
