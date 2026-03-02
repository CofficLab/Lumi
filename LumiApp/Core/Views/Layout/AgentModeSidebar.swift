import SwiftUI

/// Agent 模式侧边栏视图，显示插件提供的侧边栏内容
struct AgentModeSidebar: View {
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        let sidebarViews = pluginProvider.getSidebarViews()
        
        Group {
            if sidebarViews.isEmpty {
                // 如果没有插件提供侧边栏视图，显示默认内容
                defaultSidebar
            } else {
                // 显示所有插件提供的侧边栏视图
                VStack(spacing: 0) {
                    ForEach(Array(sidebarViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
    }

    /// 默认侧边栏视图
    private var defaultSidebar: some View {
        VStack(spacing: 8) {
            Text("Agent 模式侧边栏")
                .font(.headline)
                .padding()
            Text("暂无插件提供侧边栏视图")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Agent Mode Sidebar") {
    AgentModeSidebar()
        .frame(width: 220, height: 600)
        .inRootView()
        .environmentObject(PluginProvider.shared)
}
