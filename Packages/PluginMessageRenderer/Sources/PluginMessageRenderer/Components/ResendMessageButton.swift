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
            label: pluginLocalization.string("重发"),
            tint: theme.textSecondary.opacity(0.8),
            size: .compact,
            action: resend
        )
        .help(pluginLocalization.string("重新发送该消息"))
    }

    private func resend() {
        guard let capability else { return }
        Task {
            // 原样重发：附件由 capability 从消息 metadata 还原后随正文一起送出（#372）。
            await capability.resendMessage(message)
        }
    }
}
