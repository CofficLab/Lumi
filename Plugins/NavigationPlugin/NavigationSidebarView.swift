import SwiftUI

/// 导航侧边栏视图：提供主导航按钮
struct NavigationSidebarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 应用标题区域
            VStack(alignment: .leading, spacing: 8) {
                Text("SwiftUI Template")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Divider()
            }

            // 导航列表
            List {
                Section(header: Text("导航")) {
                    Button(action: {
                        // 主页即显示详情视图，这里可以触发特定行为
                    }) {
                        Label("主页", systemImage: .iconHome)
                    }

                    Button(action: {
                        NotificationCenter.postOpenSettings()
                    }) {
                        Label("设置", systemImage: "gear")
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
    }
}

// MARK: - Preview

#Preview("Navigation Sidebar View") {
    NavigationSidebarView()
        .inRootView()
        .frame(width: 200, height: 600)
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
