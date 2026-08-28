import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct DefaultMessageView: View {
    @LumiTheme private var theme

    let message: Message
    let verbosity: ResponseVerbosity

    var body: some View {
        MessageViewChrome(message: message, verbosity: verbosity) {
            VStack(alignment: .leading, spacing: 8) {
                if message.content.isEmpty {
                    emptyState
                } else {
                    Text(message.content)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }

                MessageDiagnosticStrip(message: message)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.appBody)
                    .foregroundColor(theme.textTertiary)

                Text(LumiPluginLocalization.string("(empty message)", bundle: .module))
                    .font(.appBody)
                    .italic()
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
            }

            Text("此消息没有正文，点按头部右侧信息图标可查看原始字段")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
        }
    }
}
