import MagicKit
import OSLog
import SwiftUI

/// 思考状态指示器
/// 显示在助手正在思考时的动画指示器
struct ThinkingIndicator: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🧠"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("思考中")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(.orange)
        }
    }
}

// MARK: - Preview

#Preview("ThinkingIndicator - Small") {
    ThinkingIndicator()
        .padding()
        .frame(width: 800, height: 600)
}

#Preview("ThinkingIndicator - Large") {
    ThinkingIndicator()
        .padding()
        .frame(width: 1200, height: 1200)
}
