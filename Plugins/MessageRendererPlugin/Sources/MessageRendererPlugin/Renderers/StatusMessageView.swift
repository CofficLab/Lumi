import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct StatusMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    var body: some View {
        if verbosity == .brief {
            // 左对齐的轻量状态行:与正文同列,带一个会呼吸的 sparkles 图标点缀,
            // 不再用独立的头像/卡片,避免与简洁的 V1 inline 风格冲突。
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.primary)
                    .frame(width: 14, height: 14)
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
        } else {
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
                    AppIdentityRow(
                        title: MessageViewHelpers.formatTimestamp(message.createdAt),
                        titleColor: theme.textSecondary
                    )

                    MessageInfoButton(message: message)
                }
            }
        }
    }
}