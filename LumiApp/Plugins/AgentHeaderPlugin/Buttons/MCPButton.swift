import SwiftUI

/// MCP 管理按钮：打开 MCP 服务器设置
/// 自治组件，使用 NotificationCenter 发送事件
struct MCPButton: View {
    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            NotificationCenter.postOpenMCPSettings()
        }) {
            Image(systemName: "server.rack")
                .font(.system(size: iconSize))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("MCP Button") {
    MCPButton()
        .padding()
        .background(Color.black)
}
