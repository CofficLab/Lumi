import OSLog
import SwiftUI

/// 应用模式内容视图
struct AppModeContentView: View {
    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏（统一侧边栏，顶部显示模式切换）
            if sidebarVisibility {
                UnifiedSidebar(sidebarVisibility: $sidebarVisibility)
                    .frame(width: 220)

                // 侧边栏与内容区的微妙分隔线
                Rectangle()
                    .fill(SwiftUI.Color.white.opacity(0.1))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }

            // 内容区域
            detailContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 创建详情内容视图
    @ViewBuilder
    private func detailContent() -> some View {
        VStack(spacing: 0) {
            // 显示当前选中的导航内容
            app.getCurrentNavigationView(pluginVM: pluginProvider)
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview("App Mode") {
    AppModeContentView(sidebarVisibility: .constant(true))
        .inRootView()
}
