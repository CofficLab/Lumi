import AppKit
import Combine
import LumiUI
import ProviderMessage
import SwiftUI

/// 聊天输入框上方的待发送附件预览。
///
/// 附件列表与移除操作全部通过 `ConversationInputViewModel` 表达，
/// 不再直接访问发送器 Provider。
///
/// 预览行本身也是一个**拖放落点**：已有附件时用户往往想「再添一张」，
/// 而此时鼠标正悬在预览区上——预览区不接拖放，第二次拖放就落到了输入框
/// 之外的空白处，看起来「没反应」。
struct AttachmentPreviewView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ConversationInputViewModel

    /// 拖放悬停态。用于给预览区加一圈高亮，告诉用户「这里能放」。
    @State private var isDropTargeted = false

    /// 日志前缀。
    private static let logPrefix = "[AttachmentPreview] "

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
                                // 位图在 ViewModel 的解码缓存里取，输入框每次按键
                                // 触发的预览重跑不再重复 Base64 解码（见 issue #1298）。
                                image: viewModel.attachmentImageDecoder.image(for: attachment),
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
                .overlay {
                    // 悬停高亮：拖放悬停时描边加粗并染上主题色。
                    //
                    // 没有这层反馈，用户看不出预览区能不能接拖放——而这正是
                    // 「拖第二张没反应」这个问题的另一半：用户根本不知道
                    // 预览区也是落点。
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isDropTargeted ? theme.primary : .clear,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                }
                .contentShape(Rectangle())
                // - Important: 类型列表**只能**声明 `.fileURL`，不能追加
                //   `.plainText` / `.text` / `.image`。
                //
                //   SwiftUI 会按这里声明的类型对 `NSItemProvider` 做**降级**：
                //   只保留能匹配声明列表的表示，把其余表示丢掉。拖入 PNG 时，
                //   声明含 `.image` 会让 provider 降级成 `public.png`，
                //   `public.file-url` 被丢弃 —— 于是 `DroppedItemResolver`
                //   既读不到 URL 也读不到纯文本，解析结果为空，拖放静默失败。
                //   声明 `.plainText` / `.text` 对 txt 同理（降级成
                //   `public.plain-text`）。
                //
                //   只声明 `.fileURL` 时，png / txt / pdf 全部保留
                //   `public.file-url`，路径拿得到。代价是纯文本拖入（编辑器里
                //   选中的路径）不再被接受 —— 那条路走输入框即可，预览区是
                //   附件区，只接文件。
                //
                //   另注意：输入框走 AppKit `NSTextView.performDragOperation`，
                //   直接从 `NSPasteboard` 读 `NSURL`，不受这里的降级影响，
                //   所以两条路径的可用内容并不相同，这是刻意的。
                .onDrop(of: AttachmentPreviewDropTypes.declared, isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    /// 处理落到预览区上的拖放。
    ///
    /// 与输入框共用 `ConversationInputViewModel.attach(droppedURL:)` 的分流规则，
    /// 因此同一个文件拖到输入框与拖到预览区会得到相同的结果。
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        ConversationInputViewModel.logger.info(
            "\(Self.logPrefix)drop reached preview, providers=\(providers.count)"
        )
        DroppedItemResolver.fileURLs(from: providers) { urls in
            ConversationInputViewModel.logger.info(
                "\(Self.logPrefix)resolved \(urls.count) url(s): \(urls.map(\.lastPathComponent).joined(separator: ","))"
            )
            for url in urls {
                viewModel.attach(droppedURL: url)
            }
        }
        return true
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
                Text(
                    attachment.textContent == nil
                        ? pluginLocalization.string("Binary file")
                        : pluginLocalization.string("Text file")
                )
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
            .accessibilityIdentifier(AttachmentPreviewAccessibility.removeFileButton)
            .accessibilityLabel(pluginLocalization.string("Remove file"))
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
    /// 已解码的位图。由 `AttachmentImageDecoder` 缓存，body 重跑时直接复用。
    let image: NSImage?
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                // - Important: 缩略图本身必须可访问且带文件名。`.help()` 只是
                //   tooltip，**不进 AX 树**，因此在没有这行时 VoiceOver 只会
                //   念出「移除图片」按钮，完全无法区分是哪张图。
                .accessibilityElement()
                .accessibilityLabel(attachment.fileName ?? attachment.mimeType)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AttachmentPreviewAccessibility.removeImageButton)
            .accessibilityLabel(pluginLocalization.string("Remove image"))
            .offset(x: 6, y: -6)
        }
        .help(attachment.fileName ?? attachment.mimeType)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
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

}
