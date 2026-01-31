import SwiftUI

/// 状态栏视图：显示插件提供的状态栏内容
struct StatusBarView: View {
    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 应用提供者环境对象
    @EnvironmentObject var appProvider: AppProvider

    var body: some View {
        HStack(spacing: 12) {
            // 插件提供的状态栏左侧内容
            ForEach(pluginProvider.getStatusBarLeadingViews().indices, id: \.self) { index in
                pluginProvider.getStatusBarLeadingViews()[index]
                    .environmentObject(appProvider)
            }

            Spacer()

            // 插件提供的状态栏右侧内容
            ForEach(pluginProvider.getStatusBarTrailingViews().indices, id: \.self) { index in
                pluginProvider.getStatusBarTrailingViews()[index]
                    .environmentObject(appProvider)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview("Status Bar View") {
    StatusBarView()
        .environmentObject(PluginProvider())
        .frame(width: 600, height: 50)
}
