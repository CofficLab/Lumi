import SwiftUI

/// 设置按钮：打开应用设置
struct SettingsButton: View {
    private let iconSize: CGFloat = 12
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            NotificationCenter.postOpenSettings()
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: iconSize))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Settings Button") {
    SettingsButton()
        .padding()
        .background(Color.black)
}
