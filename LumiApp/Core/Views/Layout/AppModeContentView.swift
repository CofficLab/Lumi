import OSLog
import SwiftUI

/// 应用模式内容视图
struct AppModeContentView: View {
    @Binding var sidebarVisibility: Bool
    
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏
            if sidebarVisibility {
                VStack(spacing: 0) {
                    // 模式切换器
                    modeSwitcher
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.top, 32)
                        .padding(.bottom, DesignTokens.Spacing.sm)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // 应用模式侧边栏
                    AppModeSidebar()
                }
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
            app.getCurrentNavigationView(pluginProvider: pluginProvider)
        }
        .frame(maxHeight: .infinity)
    }

    /// 模式切换器
    private var modeSwitcher: some View {
        Picker("模式", selection: Binding(
            get: { app.selectedMode },
            set: {
                app.selectedMode = $0
                pluginProvider.selectedMode = $0
            }
        )) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview("App Mode") {
    AppModeContentView(sidebarVisibility: .constant(true))
        .inRootView()
}
