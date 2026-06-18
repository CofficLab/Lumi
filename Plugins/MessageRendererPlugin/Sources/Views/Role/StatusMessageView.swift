import LumiCoreKit
import LumiUI
import SwiftUI

struct StatusMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage

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
                AppIdentityRow(
                    title: MessageViewHelpers.formatTimestamp(message.createdAt),
                    titleColor: theme.textSecondary
                )

                MessageInfoButton(message: message)
            }
        }
    }
}

/// 脉冲涟漪动画 —— 与对话列表 `ProcessingPulseIndicator` 风格一致。
struct PulseRipple: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .scaleEffect(isAnimating ? 1.8 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
            .allowsHitTesting(false)
    }
}
