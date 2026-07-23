import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct UserMessageView: View {
    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage, showsResendButton: true) {
            VStack(alignment: .leading, spacing: 8) {
                if !message.userImageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: message.userImageData)
                }

                if !message.content.isEmpty {
                    CollapsiblePlainText(text: message.content)
                }
            }
            .appMessageBubble(role: .user, isError: message.isError)
        }
    }
}
