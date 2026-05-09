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

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()
        let headerViews = pluginProvider.getActivePanelHeaderViews()
        let bottomViews = pluginProvider.getActivePanelBottomViews()

        Group {
            if let activeItem {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // ── 上半部分：Header + 主内容 ──
                        VStack(spacing: 1) {
                            ForEach(headerViews.indices, id: \.self) { index in
                                headerViews[index]
                            }

                            activeItem.view
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // ── 可拖拽分隔线 ──
                        if !bottomViews.isEmpty {
                            PanelResizerView()
                        }

                        // ── 下半部分：底部面板 ──
                        // 高度由 LayoutVM.editorBottomPanelHeight 控制
                        if !bottomViews.isEmpty {
                            VStack(spacing: 1) {
                                ForEach(bottomViews.indices, id: \.self) { index in
                                    bottomViews[index]
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(height: layoutVM.editorBottomPanelHeight)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
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
                        heightAtDragStart = layoutVM.editorBottomPanelHeight
                    }
                    // 向上拖拽 → translation.height 为负 → 面板变矮
                    // 向下拖拽 → translation.height 为正 → 面板变高
                    let newHeight = heightAtDragStart - value.translation.height
                    layoutVM.editorBottomPanelHeight = clamp(newHeight)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }

    private func clamp(_ height: CGFloat) -> CGFloat {
        min(max(height, minHeight), maxHeight)
    }
}
