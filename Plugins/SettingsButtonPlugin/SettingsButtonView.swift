import SwiftUI

/// 设置按钮视图：在状态栏右侧显示设置图标，点击打开设置界面
struct SettingsButtonView: View {
    @EnvironmentObject var app: AppProvider

    var body: some View {
        Button(action: {
            NotificationCenter.postOpenSettings()
        }) {
            Image(systemName: SettingsButtonPlugin.iconName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("打开设置 (⌘,)")
    }
}

// MARK: - Preview

#Preview("Settings Button") {
    HStack {
        Spacer()
        SettingsButtonView()
    }
    .padding()
    .frame(width: 200)
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
