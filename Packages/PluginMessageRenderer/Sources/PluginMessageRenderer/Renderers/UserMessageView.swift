import AgentToolKit
import KernelCore
import LocalizationKit
import LumiUI
import MarkdownKit
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct UserMessageView: View {
    let kernel: KernelCoreContainer
    let message: Message
    let verbosity: LumiResponseVerbosity

    private var isBrief: Bool { verbosity == .brief }

    var body: some View {
        // 单次取用(带进程级缓存):历史上 userImageData / decodedFileAttachments
        // 各计算两次(JSON+base64 解码),且每次滚动重物化都重复执行。
        let attachments = message.cachedDecodedAttachments
        return MessageViewChrome(kernel: kernel, message: message, showsResendButton: true, verbosity: verbosity) {
            VStack(alignment: .leading, spacing: 8) {
                if !attachments.imageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: attachments.imageData)
                }

                if !attachments.fileAttachments.isEmpty {
                    MessageFileAttachmentChips(attachments: attachments.fileAttachments)
                }

                if !message.content.isEmpty {
                    CollapsiblePlainText(text: message.content)
                }
            }
            .modifier(UserMessagePresentationModifier(isBrief: isBrief, isError: message.isError))
        }
    }
}

private struct UserMessagePresentationModifier: ViewModifier {
    @LumiTheme private var theme

    let isBrief: Bool
    let isError: Bool

    func body(content: Content) -> some View {
        if isBrief {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .foregroundColor(isError ? theme.error : theme.textPrimary)
                .background(
                    (isError ? theme.error : theme.textSecondary).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            content.appMessageBubble(role: .user, isError: isError)
        }
    }
}
