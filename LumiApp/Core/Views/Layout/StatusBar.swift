import SwiftUI

/// 底部状态栏视图
struct StatusBar: View {
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        let statusBarViews = pluginProvider.getStatusBarViews()

        return Group {
            if !statusBarViews.isEmpty {
                HStack(spacing: 12) {
                    ForEach(statusBarViews.indices, id: \.self) { index in
                        statusBarViews[index]
                            .id("status_bar_\(index)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)
                .appSurface(style: .glassUltraThick, cornerRadius: 0)
            }
        }
    }
}
