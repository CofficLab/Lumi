import SwiftUI

/// 状态栏悬停容器组件
///
/// 为状态栏插件提供统一的悬停效果，包括：
/// - 背景高亮（半透明选区颜色）
/// - 可选的 popover 详情视图
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
            .animation(DesignAnimations.Preset.fadeIn, value: isPresented)
            .onHover { hovering in
                // 仅当有详情视图时才通知协调器
                if detailView != nil {
                    coordinator.onHover(id: self.id, isHovering: hovering)
                }
            }
            .onChange(of: coordinator.visibleID) { _, visibleID in
                guard detailView != nil else { return }

                let shouldShow = (visibleID == self.id)
                if isPresented != shouldShow {
                    withAnimation(DesignAnimations.Preset.fadeIn) {
                        isPresented = shouldShow
                    }
                }
            }
            .onChange(of: isPresented) { oldValue, newValue in
                guard oldValue != newValue, detailView != nil else { return }

                // 如果是用户手动关闭，通知协调器
                if !newValue && coordinator.visibleID == self.id {
                    coordinator.close(id: self.id)
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
                if isPresented {
                    // 使用系统选区颜色的半透明版本，更符合 macOS 原生体验
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.15))
                        .transition(.opacity)
                }
            }
            .animation(DesignAnimations.Preset.fadeIn, value: isPresented)
        }
    }

    /// Popover 内容
    @ViewBuilder
    private var popoverContent: some View {
        if let detailView = detailView {
            detailView
                .onHover { hovering in
                    coordinator.onHover(id: self.id, isHovering: hovering)
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
    static func withTextDetail<C: View, D: View>(
        _ detailText: String,
        title: String? = nil,
        id: String = UUID().uuidString,
        @ViewBuilder detail: @escaping () -> D,
        @ViewBuilder content: @escaping () -> C
    ) -> StatusBarHoverContainer<C, D> {
        return StatusBarHoverContainer<C, D>(
            detailView: detail(),
            id: id,
            content: content
        )
    }

    /// 快速创建带简单文本详情的容器（简单版本）
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

// MARK: - Preview Helper

/// Preview 用的网络详情视图（提取到顶层避免 ViewBuilder 闭包内声明类型）
private struct PreviewNetworkDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("网络监控")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("下载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("1.2 MB/s")
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("上传")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("256 KB/s")
                        .font(.title2)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("基础悬停效果") {
    HStack(spacing: DesignTokens.Spacing.md) {
        StatusBarHoverContainer {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                Text("1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }

        StatusBarHoverContainer {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                Text("main")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    .padding()
    .background(DesignTokens.Color.basePalette.deepBackground)
}

#Preview("带 Popover 详情") {
    HStack(spacing: DesignTokens.Spacing.md) {
        StatusBarHoverContainer(
            detailView: VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("应用版本")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Divider()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("版本号:")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("1.0.0")
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    }
                    HStack {
                        Text("构建号:")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("123")
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    }
                    HStack {
                        Text("发布日期:")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("2024-01-15")
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    }
                }
            },
            id: "version-preview"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                Text("1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    .padding()
    .background(DesignTokens.Color.basePalette.deepBackground)
}
