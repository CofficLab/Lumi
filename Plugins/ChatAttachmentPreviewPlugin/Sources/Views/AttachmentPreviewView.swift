import AppKit
import LumiKernel
import LumiUI
import SwiftUI

/// 附件预览主视图
///
/// 通过 `ObservableMessageSendingBox` 间接观察 `MessageSending`(因为 SwiftUI
/// 的 `@ObservedObject` 不支持 `any` existentials)。
///
/// 设计原则:
/// - 不持有任何本地状态
/// - 空附件时整体不渲染(0 高度,无 padding/background)
/// - 图片解码失败时显示占位灰块,但仍可删除
struct AttachmentPreviewView: View {
    @ObservedObject var box: ObservableMessageSendingBox
    @LumiTheme private var theme

    private var messageSend: any MessageSending { box.service }

    private var attachments: [LumiImageAttachment] {
        messageSend.pendingAttachments
    }

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        AttachmentThumbnail(
                            attachment: attachment,
                            onRemove: {
                                messageSend.removeAttachment(id: attachment.id)
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
}

/// 单个附件缩略图:72x72 图片 + 右上角"×"删除按钮
private struct AttachmentThumbnail: View {
    let attachment: LumiImageAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
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
            // 解码失败占位
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
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