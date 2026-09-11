import AppKit
import Combine
import LumiUI
import ProviderMessage
import SwiftUI

/// 聊天输入框上方的待发送附件预览。
///
/// 附件列表与移除操作全部通过 `ConversationInputViewModel` 表达，
/// 不再直接访问发送器 Provider。
struct AttachmentPreviewView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ConversationInputViewModel

    init(viewModel: ConversationInputViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        let _ = viewModel.revision

        Group {
            if !viewModel.imageAttachments.isEmpty || !viewModel.fileAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.imageAttachments) { attachment in
                            AttachmentThumbnail(
                                attachment: attachment,
                                onRemove: {
                                    viewModel.removeImageAttachment(id: attachment.id)
                                }
                            )
                        }

                        ForEach(viewModel.fileAttachments) { attachment in
                            FileAttachmentChip(
                                attachment: attachment,
                                onRemove: {
                                    viewModel.removeFileAttachment(id: attachment.id)
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
}

private struct FileAttachmentChip: View {
    @LumiTheme private var theme

    let attachment: UserFileAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.textContent == nil ? "doc.fill" : "doc.text")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(theme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(attachment.textContent == nil ? "Binary file" : "Text file")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 150, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove file")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.textPrimary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.textPrimary.opacity(0.08), lineWidth: 1)
        )
        .help(attachment.fileName)
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
