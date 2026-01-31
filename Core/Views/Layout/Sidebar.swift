import SwiftUI

/// 侧边栏视图，显示插件提供的导航入口
struct Sidebar: View {
    /// 应用提供者环境对象
    @EnvironmentObject var appProvider: AppProvider

    /// 插件提供者环境对象
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        VStack(spacing: 0) {
            // 导航列表
            if !appProvider.navigationEntries.isEmpty {
                List(appProvider.navigationEntries, selection: $appProvider.selectedNavigationEntry) { entry in
                    NavigationEntryRow(entry: entry)
                        .tag(entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appProvider.selectNavigationEntry(entry)
                        }
                }
                .listStyle(.sidebar)
            } else {
                // 空状态
                emptyState
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
        .onAppear {
            loadNavigationEntries()
        }
    }

    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("暂无导航")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("插件未提供导航入口")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 加载所有插件提供的导航入口
    private func loadNavigationEntries() {
        let entries = pluginProvider.getNavigationEntries()

        // 只在导航入口为空时注册
        if appProvider.navigationEntries.isEmpty {
            appProvider.registerNavigationEntries(entries)
        }
    }
}

/// 导航入口行视图
struct NavigationEntryRow: View {
    let entry: NavigationEntry

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: entry.icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // 标题
            Text(entry.title)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
