import OSLog
import SwiftUI

/// Agent 模式内容视图（三栏布局：左侧栏 + 详情栏 + 右侧栏）
struct AgentModeContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "🤖"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalProvider
    @EnvironmentObject var pluginProvider: PluginProvider

    var body: some View {
        VStack(spacing: 0) {
            // 主内容区域（三栏布局）
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部状态栏
            statusBar
        }
        .ignoresSafeArea()
        .task {
            if Self.verbose {
                let rightViews = pluginProvider.getRightViews()
                os_log("\(Self.emoji) Agent Mode: 右侧栏视图数量=\(rightViews.count)")
            }
        }
    }

    // MARK: - 主内容区域
    
    /// 主内容区域（三栏布局）
    private var mainContent: some View {
        HSplitView {
            // 第一栏：左侧栏（统一侧边栏，顶部显示模式切换）
            if sidebarVisibility {
                sidebarColumn
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 400)
            }

            // 第二栏 + 第三栏：嵌套 HSplitView
            rightAndDetailColumns
        }
        .id("agentModeHSplitView")
    }

    // MARK: - 底部状态栏
    
    /// 底部状态栏
    private var statusBar: some View {
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
                .background(DesignTokens.Material.glassThin)
            }
        }
    }

    // MARK: - 子视图

    /// 左侧栏列
    private var sidebarColumn: some View {
        UnifiedSidebar(sidebarVisibility: $sidebarVisibility)
    }

    /// 右侧栏和详情栏（嵌套 HSplitView）
    private var rightAndDetailColumns: some View {
        let rightViews = pluginProvider.getRightViews()

        return Group {
            if rightViews.isEmpty {
                // 如果没有右侧栏视图，直接显示详情栏
                detailColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 有右侧栏时，使用 HSplitView 分隔
                HSplitView {
                    // 第二栏：详情栏
                    detailColumn
                        .frame(minWidth: 200, idealWidth: 300)

                    // 第三栏：右侧栏
                    rightColumn(rightViews: rightViews)
                        .frame(minWidth: 200, idealWidth: 300)
                }
                .id("agentModeRightDetailHSplitView")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 右侧栏
    private func rightColumn(rightViews: [AnyView]) -> some View {
        VStack(spacing: 0) {
            // 修复：使用稳定 ID 而不是 offset，避免 AttributeGraph 崩溃
            ForEach(rightViews.indices, id: \.self) { index in
                rightViews[index]
                    .id("right_\(index)")
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
        .ignoresSafeArea()
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
                // 修复：使用稳定 ID 而不是 offset，避免 AttributeGraph 崩溃
                VStack(spacing: 0) {
                    ForEach(headerViews.indices, id: \.self) { index in
                        headerViews[index]
                            .id("detail_header_\(index)")
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
                // 修复：使用稳定 ID 而不是 offset，避免 AttributeGraph 崩溃
                VStack(spacing: 0) {
                    ForEach(middleViews.indices, id: \.self) { index in
                        middleViews[index]
                            .id("detail_middle_\(index)")
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
                // 修复：使用稳定 ID 而不是 offset，避免 AttributeGraph 崩溃
                VStack(spacing: 0) {
                    ForEach(bottomViews.indices, id: \.self) { index in
                        bottomViews[index]
                            .id("detail_bottom_\(index)")
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
