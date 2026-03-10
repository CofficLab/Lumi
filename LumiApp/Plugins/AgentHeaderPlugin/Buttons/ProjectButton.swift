import SwiftUI

/// 项目管理按钮：打开项目选择器
/// 自治组件，使用 NotificationCenter 发送事件
struct ProjectButton: View {
    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            NotificationCenter.postOpenProjectSelector()
        }) {
            Image(systemName: "folder.badge.gearshape")
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

#Preview("Project Button") {
    ProjectButton()
        .padding()
        .background(Color.black)
}
