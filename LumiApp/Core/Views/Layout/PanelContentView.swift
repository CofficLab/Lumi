import SwiftUI

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 布局采用上下分离结构（参考 VSCode）：
/// - 上半部分：Header + 主内容区（占据剩余空间）
/// - 中间：可拖拽分隔线，调节底部面板高度
/// - 下半部分：底部面板区（高度由 LayoutVM 管理，LayoutPlugin 持久化）
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    /// 分隔线高度
    private let resizerHeight: CGFloat = 6

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let hasBottomTabs = pluginProvider.hasBottomPanelTabs()

        Group {
            if let activeItem {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // ── 上半部分：Header + 主内容 ──
                        // 使用计算高度，避免与底部面板的 maxHeight: .infinity 竞争
                        VStack(spacing: 1) {
                            ForEach(headerViews.indices, id: \.self) { index in
                                headerViews[index]
                            }

                            activeItem.view
                        }
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                                - layoutVM.editorBottomPanelHeight
                                - (hasBottomTabs ? resizerHeight : 0)
                        )

                        // ── 可拖拽分隔线 ──
                        if hasBottomTabs {
                            PanelResizerView()
                        }

                        // ── 下半部分：全局底部面板 ──
                        // 由内核统一维护，聚合所有插件提供的 BottomPanelTab
                        if hasBottomTabs {
                            BottomPanelBarView()
                                .frame(width: geometry.size.width)
                                .frame(height: layoutVM.editorBottomPanelHeight)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Panel Resizer

/// 面板高度拖拽调节器
///
/// 通过拖拽分隔线来调整底部面板的高度。
/// 高度值存储在 LayoutVM.editorBottomPanelHeight，
/// 由 LayoutPlugin 持久化到磁盘。
struct PanelResizerView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var layoutVM: LayoutVM

    /// 是否正在拖拽
    @State private var isDragging = false

    /// 拖拽开始时的底部面板高度
    @State private var heightAtDragStart: CGFloat = 0

    /// 底部面板最小高度（仅 Tab 栏）
    private let minHeight: CGFloat = 33

    /// 底部面板最大高度
    private let maxHeight: CGFloat = 600

    var body: some View {
        ZStack {
            // 可点击的宽区域
            Rectangle()
                .fill(isDragging
                    ? themeVM.activeAppTheme.accentColors().primary.opacity(0.15)
                    : Color.clear)
                .frame(height: 6)

            // 视觉分隔线
            Rectangle()
                .fill(isDragging
                    ? themeVM.activeAppTheme.accentColors().primary.opacity(0.6)
                    : themeVM.activeAppTheme.workspaceTextColor().opacity(0.08))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering || isDragging {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        layoutVM.isDraggingBottomPanel = true
                        // 记录拖拽开始时的展开状态，避免拖拽过程中 Tab 栏样式抖动
                        layoutVM.wasExpandedBeforeDrag = layoutVM.editorBottomPanelHeight > 33
                        heightAtDragStart = layoutVM.editorBottomPanelHeight
                    }
                    // 向上拖拽 → translation.height 为负 → 面板变矮
                    // 向下拖拽 → translation.height 为正 → 面板变高
                    let newHeight = heightAtDragStart - value.translation.height
                    layoutVM.editorBottomPanelHeight = clamp(newHeight)
                }
                .onEnded { _ in
                    isDragging = false
                    layoutVM.isDraggingBottomPanel = false
                    // 拖拽结束时才持久化，避免拖拽过程中频繁 I/O 阻塞
                    LayoutPluginLocalStore.shared.saveEditorBottomPanelHeight(layoutVM.editorBottomPanelHeight)
                }
        )
    }

    private func clamp(_ height: CGFloat) -> CGFloat {
        min(max(height, minHeight), maxHeight)
    }
}
