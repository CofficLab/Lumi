import LumiKernel
import LumiUI
import SwiftUI

struct UserMessageView: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
    let kernel: LumiKernel
    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    private var isBrief: Bool { verbosity == .brief }

    var body: some View {
        MessageViewChrome(kernel: kernel, message: message, showRawMessage: $showRawMessage, showsResendButton: true) {
            VStack(alignment: .leading, spacing: 8) {
                if !message.userImageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: message.userImageData)
                }

                if !message.decodedFileAttachments.isEmpty {
                    MessageFileAttachmentChips(attachments: message.decodedFileAttachments)
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
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            content.appMessageBubble(role: .user, isError: isError)
        }
    }
}
