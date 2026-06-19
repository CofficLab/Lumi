import SwiftUI

/// 脉冲涟漪动画 —— 从中心向外扩散并渐隐，统一用于处理中状态指示。
public struct PulseRipple: View {
    public let color: Color
    @State private var isAnimating = false

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
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
