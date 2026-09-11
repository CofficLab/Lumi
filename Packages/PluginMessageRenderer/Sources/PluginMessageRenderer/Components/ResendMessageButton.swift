import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

struct ResendMessageButton: View {
    @LumiTheme private var theme

    let capability: (any MessageRendererCapability)?
    let message: Message

    var body: some View {
        AppIconButton(
            systemImage: "arrow.clockwise",
            label: LumiPluginLocalization.string("重发", bundle: .module),
            tint: theme.textSecondary.opacity(0.8),
            size: .compact,
            action: resend
        )
        .help(LumiPluginLocalization.string("重新发送该消息", bundle: .module))
    }

    private func resend() {
        guard let capability else { return }
        Task {
            // 新版 MessageSendingProviding 无 id 级重发；以相同内容再次发送，行为等价。
            await capability.resendMessage(
                content: message.content,
                conversationID: message.conversationID
            )
        }
    }
}
