import SwiftUI

/// 状态栏悬停容器组件
///
/// 为状态栏插件提供统一的悬停效果，包括：
/// - 悬停时背景高亮（半透明选区颜色）
/// - 点击时显示 popover 详情视图
/// - 多个容器之间的互斥显示（通过 HoverCoordinator）
/// - 符合设计系统的动画和样式
///
/// ## 使用示例
///
/// ### 基础用法（仅背景高亮）
/// ```swift
/// StatusBarHoverContainer {
///     HStack {
///         Image(systemName: "tag.fill")
///         Text("1.0.0")
///     }
/// }
/// ```
///
/// ### 带详情 Popover
/// ```swift
/// StatusBarHoverContainer(detailView: AppVersionDetailView()) {
///     HStack {
///         Image(systemName: "tag.fill")
///         Text("1.0.0")
///     }
/// }
/// ```
///
/// ### 自定义配置
/// ```swift
/// StatusBarHoverContainer(
///     detailView: NetworkDetailView(),
///     popoverWidth: 500,
///     id: "network-status"
/// ) {
///     NetworkStatusView()
/// }
/// ```
struct StatusBarHoverContainer<Content: View, Detail: View>: View {
    // MARK: - Properties

    /// 详情视图（在 popover 中显示），为 nil 则只显示悬停背景高亮
    let detailView: Detail?

    /// 内容视图构建器
    let content: Content

    /// Popover 宽度（默认 480）
    let popoverWidth: CGFloat

    /// 唯一标识符，用于区分不同的悬停容器
    let id: String

    /// Popover 箭头方向（默认 .top）
    let arrowEdge: Edge

    // MARK: - State

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @State private var isPresented = false
    @State private var isHovering = false

    // MARK: - Initializers

    /// 创建带详情视图的容器
    /// - Parameters:
    ///   - detailView: 详情视图
    ///   - popoverWidth: Popover 宽度
    ///   - id: 唯一标识符
    ///   - arrowEdge: Popover 箭头方向
    ///   - content: 内容视图
    init(
        detailView: Detail,
        popoverWidth: CGFloat = 480,
        id: String = UUID().uuidString,
        arrowEdge: Edge = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.detailView = detailView
        self.content = content()
        self.popoverWidth = popoverWidth
        self.id = id
        self.arrowEdge = arrowEdge
    }

    /// 创建仅悬停背景的容器（无 popover）
    /// - Parameters:
    ///   - id: 唯一标识符
    ///   - content: 内容视图
    init(
        id: String = UUID().uuidString,
        @ViewBuilder content: () -> Content
    ) where Detail == EmptyView {
        self.detailView = nil
        self.content = content()
        self.popoverWidth = 480
        self.id = id
        self.arrowEdge = .top
    }

    // MARK: - Body

    var body: some View {
        return content
            .background(hoverBackground)
            .animation(DesignAnimations.Preset.fadeIn, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                // 仅当有详情视图时才响应点击
                guard detailView != nil else { return }
                
                // 切换显示状态
                withAnimation(DesignAnimations.Preset.fadeIn) {
                    if isPresented {
                        // 如果当前已显示，则关闭
                        isPresented = false
                        coordinator.close(id: self.id)
                    } else {
                        // 如果当前未显示，先关闭其他的，再显示当前的
                        coordinator.closeAll()
                        isPresented = true
                        coordinator.open(id: self.id)
                    }
                }
            }
            .if(detailView != nil) { view in
                view.popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                    popoverContent
                }
            }
    }

    // MARK: - Private Views

    /// 悬停背景（使用系统选区颜色）
    private var hoverBackground: some View {
        GeometryReader { geometry in
            ZStack {
                if isHovering {
                    // 使用系统选区颜色的半透明版本，更符合 macOS 原生体验
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.15))
                        .transition(.opacity)
                }
            }
        }
    }

    /// Popover 内容
    @ViewBuilder
    private var popoverContent: some View {
        if let detailView = detailView {
            detailView
                .onHover { hovering in
                    // 保持 popover 打开状态
                    if hovering {
                        coordinator.open(id: self.id)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(width: popoverWidth)
                .background(DesignTokens.Material.glass)
        }
    }
}

// MARK: - Convenience Initializers

extension StatusBarHoverContainer {
    /// 快速创建带简单文本详情的容器
    /// - Parameters:
    ///   - detailText: 详情文本
    ///   - title: 详情标题
    ///   - content: 内容视图
    static func withTextDetail<C: View>(
        _ detailText: String,
        title: String? = nil,
        id: String = UUID().uuidString,
        @ViewBuilder content: @escaping () -> C
    ) -> StatusBarHoverContainer<C, AnyView> {
        let detailContent = AnyView(
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                if let title = title {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                Text(detailText)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .textSelection(.enabled)
            }
        )

        return StatusBarHoverContainer<C, AnyView>(
            detailView: detailContent,
            id: id,
            content: content
        )
    }
}
