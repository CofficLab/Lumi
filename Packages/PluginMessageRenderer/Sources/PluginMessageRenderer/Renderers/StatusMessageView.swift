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

struct StatusMessageView: View {
    @LumiTheme private var theme

    let message: Message
    let verbosity: ResponseVerbosity
    @State private var showInfoPopover = false
    /// 悬停态:时间戳与操作按钮仅在悬停(或 info popover 打开)时物化,
    /// 与 `MessageViewChrome` 的 header 行为保持一致。
    @State private var isHovered = false

    var body: some View {
        CompactMessageHeaderView {
            HStack(alignment: .center, spacing: 8) {
                ChatAvatarView(kind: .status)
                    .overlay(alignment: .center) {
                        PulseRipple(color: theme.primary)
                    }

                Text(message.content)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                // 时间戳与操作按钮仅在悬停(或 info popover 打开)时物化,
                // 与 `MessageViewChrome` 的 header 行为保持一致。
                if isHovered || showInfoPopover {
                    AppIdentityRow(
                        title: MessageViewHelpers.formatTimestamp(message.createdAt),
                        titleColor: theme.textSecondary
                    )
                }

                if message.role != .status {
                    MessageInfoButton(
                        message: message,
                        isPresented: $showInfoPopover
                    )
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
