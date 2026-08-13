import KernelLumi
import LumiUI
import SwiftUI

struct ResendMessageButton: View {
    @LumiTheme private var theme

    let kernel: KernelLumi
    let message: LumiChatMessage

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
        Task {
            await kernel.resendMessage(id: message.id, in: message.conversationID)
        }
    }
}
