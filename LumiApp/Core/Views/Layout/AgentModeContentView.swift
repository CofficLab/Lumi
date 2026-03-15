import OSLog
import SwiftUI

/// Agent 模式内容视图（三栏布局：左侧栏 + 详情栏 + 右侧栏）
struct AgentModeContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "🤖"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    @Binding var sidebarVisibility: Bool

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var providerRegistry: ProviderRegistry

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
                let rightHeaderViews = pluginProvider.getRightHeaderViews()
                let rightMiddleViews = pluginProvider.getRightMiddleViews()
                let rightBottomViews = pluginProvider.getRightBottomViews()
                os_log("\(Self.emoji) Agent Mode: 右侧栏头部=\(rightHeaderViews.count), 中间=\(rightMiddleViews.count), 底部=\(rightBottomViews.count)")
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
                .frame(height: 32)
                .background(DesignTokens.Material.glassUltraThick)
            }
        }
    }

    // MARK: - 子视图

    /// 左侧栏列
    private var sidebarColumn: some View {
        UnifiedSidebar(sidebarVisibility: $sidebarVisibility)
    }

    /// 右侧栏和详情栏（嵌套 HSplitView）
    @ViewBuilder
    private var rightAndDetailColumns: some View {
        if providerRegistry.providerTypes.isEmpty {
            // 没有任何 LLM 供应商可用时，仅在右侧区域显示提示，保留左侧栏以便用户切换模式
            missingProviderView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let detailViews = pluginProvider.getDetailViews()

            HSplitView {
                // 第二栏：详情栏（仅当有插件提供详情视图时显示）
                if !detailViews.isEmpty {
                    detailContentColumn
                        .frame(minWidth: 200, idealWidth: 300)
                }

                // 第三栏：右侧栏（支持头部、中间、底部）
                rightColumn
                    .frame(minWidth: 200, idealWidth: 300)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            .id("agentModeDetailRightHSplitView")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    /// 右侧栏（支持头部、中间、底部）
    private var rightColumn: some View {
        VStack(spacing: 0) {
            // 右侧栏头部
            rightHeaderContent()

            Divider()
                .background(Color.white.opacity(0.1))

            // 右侧栏中间
            rightMiddleContent()

            Divider()
                .background(Color.white.opacity(0.1))

            // 右侧栏底部
            rightBottomContent()
        }
    }

    /// 详情栏内容（简单的 VStack 堆积）
    private var detailContentColumn: some View {
        let detailViews = pluginProvider.getDetailViews()

        return VStack(spacing: 0) {
            ForEach(detailViews.indices, id: \.self) { index in
                detailViews[index]
                    .id("detail_\(index)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 右侧栏头部内容视图
    @ViewBuilder
    private func rightHeaderContent() -> some View {
        let headerViews = pluginProvider.getRightHeaderViews()
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
                            .id("right_header_\(index)")
                    }
                }
            }
        }
        .frame(height: AppConfig.headerHeight)
    }

    /// 右侧栏中间内容视图
    @ViewBuilder
    private func rightMiddleContent() -> some View {
        let middleViews = pluginProvider.getRightMiddleViews()
        Group {
            if middleViews.isEmpty {
                // 如果没有插件提供中间视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的中间视图
                VStack(spacing: 0) {
                    ForEach(middleViews.indices, id: \.self) { index in
                        middleViews[index]
                            .id("right_middle_\(index)")
                    }
                }
            }
        }
    }

    /// 右侧栏底部内容视图（输入区域）
    @ViewBuilder
    private func rightBottomContent() -> some View {
        let bottomViews = pluginProvider.getRightBottomViews()
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
                            .id("right_bottom_\(index)")
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

    /// 缺少供应商插件时的提示视图
    private var missingProviderView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.yellow)
            Text("Agent 模式不可用")
                .font(.title2)
                .fontWeight(.semibold)
            Text("当前没有任何 LLM 供应商插件已注册。\n请安装并启用至少一个提供 LLM 供应商的插件后重试。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

#Preview("Agent Mode") {
    AgentModeContentView(sidebarVisibility: .constant(true))
        .inRootView()
}
