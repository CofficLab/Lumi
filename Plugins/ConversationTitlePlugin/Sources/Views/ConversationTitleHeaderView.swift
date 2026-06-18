import LumiUI
import SwiftUI

struct ConversationTitleHeaderView: View {
    @LumiTheme private var theme

    let title: String
    let isSending: Bool

    var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.appMicro)
                    .foregroundColor(theme.primary)

                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

            if isSending {
                BreathingPulseIndicator(color: theme.primary)
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
