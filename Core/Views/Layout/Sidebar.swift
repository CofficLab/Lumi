import SwiftUI

/// 侧边栏视图，显示导航和插件列表
struct Sidebar: View {
    /// 应用提供者环境对象
    @EnvironmentObject var appProvider: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    /// 缓存插件提供的侧边栏视图
    @State private var sidebarViews: [(plugin: any SuperPlugin, view: AnyView)] = []

    var body: some View {
        VStack(spacing: 0) {
            // 插件提供的侧边栏视图
            if !sidebarViews.isEmpty {
                VStack(spacing: 0) {
                    ForEach(sidebarViews.indices, id: \.self) { index in
                        sidebarViews[index].view
                    }

                    Spacer()
                }
            } else {
                // 如果没有插件提供侧边栏视图，显示默认内容
                defaultSidebarContent
            }
        }
        .frame(minWidth: 200)
        .onAppear(perform: updateCachedViews)
        .onChange(of: pluginProvider.plugins.count, updateCachedViews)
    }

    /// 默认侧边栏内容（当没有插件提供侧边栏视图时显示）
    private var defaultSidebarContent: some View {
        VStack(spacing: 0) {
            Text("侧边栏")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            Spacer()
        }
    }

    /// 更新缓存的视图
    private func updateCachedViews() {
        sidebarViews = pluginProvider.plugins.compactMap { plugin -> (plugin: any SuperPlugin, view: AnyView)? in
            if let view = plugin.addSidebarView() {
                return (plugin, view)
            }
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    Sidebar()
        .inRootView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
