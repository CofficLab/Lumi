import SwiftUI

/// 设置按钮：打开应用设置
struct SettingsButton: View {
    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            NotificationCenter.postOpenSettings()
        }) {
            Image(systemName: "gearshape")
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

#Preview("Settings Button") {
    SettingsButton()
        .padding()
        .background(Color.black)
}
