import LumiUI
import SwiftUI

struct ConversationTitleHeaderView: View {
    @LumiTheme private var theme

    let title: String
    let isSending: Bool

    var body: some View {
        AppToolbarContainer(
            padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        ) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(theme.primary)

                Text(title)
                    .font(.appSectionTitle)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                if isSending {
                    BreathingPulseIndicator(color: theme.primary)
                }

                Spacer()
            }
        }
    }
}

/// 呼吸式脉冲动画指示器
private struct BreathingPulseIndicator: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.8 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
