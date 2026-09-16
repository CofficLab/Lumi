import LumiUI
import ProviderMessage
import SwiftUI

/// AgentLoop 自动重试时间线标记。
struct AgentLoopRetryMessageView: View {
    @LumiTheme private var theme

    let message: Message

    private let dividerHeight: CGFloat = 1

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .medium))

            Text(message.content)
                .font(.appCaption)
                .lineLimit(1)

            Text(MessageViewHelpers.formatTimestamp(message.createdAt))
                .font(.system(size: 10))
                .lineLimit(1)

            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.content)
    }
}
