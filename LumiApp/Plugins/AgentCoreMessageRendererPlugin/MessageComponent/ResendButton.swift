import SwiftUI

/// 重发按钮组件
struct ResendButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                Text("重发")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help("重新发送该消息")
    }
}

#Preview {
    ResendButton { }
        .padding()
}
