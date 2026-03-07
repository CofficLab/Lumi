import OSLog
import SwiftUI

/// Agent 模式内容视图（三栏布局：侧边栏 + 中间栏 + 详情栏）
struct AgentModeContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "🤖"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalProvider
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
            AppModeSwitcherView()
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
        VStack(spacing: 0) {
            // 详情栏头部
            detailHeaderContent()

            Divider()
                .background(Color.white.opacity(0.1))

            // 详情栏中间（消息列表）
            detailMiddleContent()

            Divider()
                .background(Color.white.opacity(0.1))

            // 详情栏底部（输入区域）
            detailBottomContent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Agent 模式的详情头部内容视图
    @ViewBuilder
    private func detailHeaderContent() -> some View {
        let headerViews = pluginProvider.getDetailHeaderViews()
        Group {
            if headerViews.isEmpty {
                // 如果没有插件提供头部视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的头部视图
                VStack(spacing: 0) {
                    ForEach(Array(headerViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
    }

    /// Agent 模式的详情中间内容视图（消息列表）
    @ViewBuilder
    private func detailMiddleContent() -> some View {
        let middleViews = pluginProvider.getDetailMiddleViews()
        Group {
            if middleViews.isEmpty {
                // 如果没有插件提供中间视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的中间视图
                VStack(spacing: 0) {
                    ForEach(Array(middleViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
    }

    /// Agent 模式的详情底部内容视图（输入区域）
    @ViewBuilder
    private func detailBottomContent() -> some View {
        let bottomViews = pluginProvider.getDetailBottomViews()
        Group {
            if bottomViews.isEmpty {
                // 如果没有插件提供底部视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的底部视图
                VStack(spacing: 0) {
                    ForEach(Array(bottomViews.enumerated()), id: \.offset) { _, view in
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
}

#Preview("Agent Mode") {
    AgentModeContentView(sidebarVisibility: .constant(true))
        .inRootView()
}
