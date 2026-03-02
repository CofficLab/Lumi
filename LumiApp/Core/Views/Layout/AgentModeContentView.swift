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
    
    // 可调整的列宽度（使用 AppStorage 持久化）
    @AppStorage("agentSidebarWidth") private var sidebarWidth: Double = 220
    @AppStorage("agentMiddleWidth") private var middleWidth: Double = 300
    
    // 最小宽度约束
    private let minSidebarWidth: Double = 150
    private let maxSidebarWidth: Double = 400
    private let minMiddleWidth: Double = 200
    private let maxMiddleWidth: Double = 600
    
    // 拖拽状态
    @State private var isDraggingSidebarDivider = false
    @State private var isDraggingMiddleDivider = false

    var body: some View {
        HStack(spacing: 0) {
            // 第一栏：侧边栏
            if sidebarVisibility {
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
                .frame(width: sidebarWidth)

                // 侧边栏与中间栏的分隔线（可拖拽）
                dividerView(isDragging: $isDraggingSidebarDivider)
                    .frame(width: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = value.translation.width
                                let newWidth = sidebarWidth + delta
                                if newWidth >= minSidebarWidth && newWidth <= maxSidebarWidth {
                                    sidebarWidth = newWidth
                                }
                            }
                            .onEnded { _ in
                                isDraggingSidebarDivider = false
                            }
                    )
                    .onHover { hovering in
                        if !isDraggingMiddleDivider {
                            isDraggingSidebarDivider = hovering
                        }
                    }
            }

            // 第二栏：中间栏（文件预览等）
            let middleViews = pluginProvider.getMiddleViews()
            if !middleViews.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(middleViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
                .frame(width: middleWidth)

                // 中间栏与详情栏的分隔线（可拖拽）
                dividerView(isDragging: $isDraggingMiddleDivider)
                    .frame(width: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = value.translation.width
                                let newWidth = middleWidth + delta
                                if newWidth >= minMiddleWidth && newWidth <= maxMiddleWidth {
                                    middleWidth = newWidth
                                }
                            }
                            .onEnded { _ in
                                isDraggingMiddleDivider = false
                            }
                    )
                    .onHover { hovering in
                        if !isDraggingSidebarDivider {
                            isDraggingMiddleDivider = hovering
                        }
                    }
            }

            // 第三栏：内容区域（详情栏）
            agentDetailContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if Self.verbose {
                let sidebarViews = pluginProvider.getSidebarViews()
                let middleViews = pluginProvider.getMiddleViews()
                os_log("\(Self.emoji) Agent Mode: 侧边栏视图数量=\(sidebarViews.count), 中间栏视图数量=\(middleViews.count)")
            }
        }
    }
    
    /// 可拖拽分隔线视图
    private func dividerView(isDragging: Binding<Bool>) -> some View {
        Rectangle()
            .fill(isDragging.wrappedValue ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1))
            .frame(width: 1)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.15), value: isDragging.wrappedValue)
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