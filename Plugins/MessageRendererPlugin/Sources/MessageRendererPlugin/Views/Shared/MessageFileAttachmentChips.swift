import LumiKernel
import LumiUI
import SwiftUI

/// 消息气泡内展示文件附件的只读 chip 列(横向滚动)。
///
/// 与「附件预览区」(`ChatAttachmentPreviewPlugin`)的 chip 区别在于:这里展示的是
/// **已随消息发出**的附件,因此没有删除按钮,仅作回看。
struct MessageFileAttachmentChips: View {
    let attachments: [LumiFileAttachment]
    @LumiTheme private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    FileChip(attachment: attachment)
                }
            }
        }
    }

    private struct FileChip: View {
        @LumiTheme private var theme
        let attachment: LumiFileAttachment

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(attachment.fileName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(kindLabel)
                        .font(.system(size: 10))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.textPrimary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.textPrimary.opacity(0.08), lineWidth: 1)
            )
        }

        private var iconName: String {
            attachment.textContent == nil ? "doc.fill" : "doc.text"
        }

        private var kindLabel: String {
            attachment.textContent == nil ? "Binary file" : "Text file"
        }
    }
}
