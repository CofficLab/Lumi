import OSLog
import SwiftUI

/// Agent 模式内容视图（三栏布局：侧边栏 + 中间栏 + 详情栏）
struct AgentModeContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "🤖"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false
    
    @Binding var sidebarVisibility: Bool
    
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        HSplitView {
            // 第一栏：侧边栏
            if sidebarVisibility {
                sidebarColumn
                    .frame(minWidth: 150, idealWidth: 220, maxWidth: 400)
            }
            
            // 第二栏 + 第三栏：嵌套 HSplitView
            middleAndDetailColumns
        }
        .task {
            if Self.verbose {
                let sidebarViews = pluginProvider.getSidebarViews()
                let middleViews = pluginProvider.getMiddleViews()
                os_log("\(Self.emoji) Agent Mode: 侧边栏视图数量=\(sidebarViews.count), 中间栏视图数量=\(middleViews.count)")
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 侧边栏列
    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            // 模式切换器
            modeSwitcher
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, 32)
                .padding(.bottom, DesignTokens.Spacing.sm)

            Divider()
                .background(Color.white.opacity(0.1))

            // 插件提供的侧边栏视图（垂直堆叠）
            AgentModeSidebar()
        }
    }
    
    /// 中间栏和详情栏（嵌套 HSplitView）
    private var middleAndDetailColumns: some View {
        let middleViews = pluginProvider.getMiddleViews()
        
        return Group {
            if middleViews.isEmpty {
                // 如果没有中间栏视图，直接显示详情栏
                detailColumn
            } else {
                // 有中间栏时，使用 HSplitView 分隔
                HSplitView {
                    // 第二栏：中间栏
                    middleColumn(middleViews: middleViews)
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: 600)
                    
                    // 第三栏：详情栏
                    detailColumn
                }
            }
        }
    }
    
    /// 中间栏
    private func middleColumn(middleViews: [AnyView]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(middleViews.enumerated()), id: \.offset) { _, view in
                view
            }
        }
    }
    
    /// 详情栏
    private var detailColumn: some View {
        agentDetailContent()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Agent 模式的详情内容视图（显示插件提供的详情视图）
    @ViewBuilder
    private func agentDetailContent() -> some View {
        let detailViews = pluginProvider.getDetailViews()
        Group {
            if detailViews.isEmpty {
                // 如果没有插件提供详情视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的详情视图
                VStack(spacing: 0) {
                    ForEach(Array(detailViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
    }

    /// 默认详情视图（当没有插件提供详情视图时显示）
    private var defaultDetailView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("欢迎使用 Lumi")
                .font(.title)
                .fontWeight(.bold)
            Text("请从侧边栏选择一个导航入口")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview("Agent Mode") {
    AgentModeContentView(sidebarVisibility: .constant(true))
        .inRootView()
        .environmentObject(AppProvider.shared)
        .environmentObject(PluginProvider.shared)
}
