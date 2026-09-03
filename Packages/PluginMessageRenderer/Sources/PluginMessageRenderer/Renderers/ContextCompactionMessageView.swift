import LumiUI
import ProviderMessage
import SwiftUI

/// Low-emphasis timeline marker shown after the context has been compacted.
struct ContextCompactionMessageView: View {
    @LumiTheme private var theme

    let message: Message

    /// 时间线横线的固定高度选 1pt，与 `AppLabeledDivider` 的风格一致。
    /// 避免裸 `Rectangle()` 在 HStack 中横向拉伸时被撑到整行高度（显得过粗）。
    private let dividerHeight: CGFloat = 1

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider.opacity(0.7))
                .frame(height: dividerHeight)
                .frame(maxWidth: .infinity)

            Image(systemName: "arrow.triangle.2.circlepath")
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
