import SwiftUI

/// Shadow 强度级别
public enum AppShadowLevel: Equatable {
    case none      // 无阴影
    case xs        // 极轻微
    case sm        // 轻微
    case md        // 中等
    case lg        // 较强
    case xl        // 强
    case xxl       // 极强
    case xxxl      // 超强

    var color: Color {
        switch self {
        case .none: return .clear
        case .xs: return .black.opacity(0.02)
        case .sm: return .black.opacity(0.04)
        case .md: return .black.opacity(0.06)
        case .lg: return .black.opacity(0.10)
        case .xl: return .black.opacity(0.15)
        case .xxl: return .black.opacity(0.20)
        case .xxxl: return .black.opacity(0.25)
        }
    }

    var radius: CGFloat {
        switch self {
        case .none: return 0
        case .xs: return 2
        case .sm: return 4
        case .md: return 6
        case .lg: return 8
        case .xl: return 12
        case .xxl: return 16
        case .xxxl: return 20
        }
    }

    var y: CGFloat {
        switch self {
        case .none: return 0
        case .xs: return 1
        case .sm: return 2
        case .md: return 3
        case .lg: return 4
        case .xl: return 6
        case .xxl: return 8
        case .xxxl: return 10
        }
    }

    /// 承接阴影的高度：与 `radius` 成正比，覆盖阴影自然衰减的范围。
    var undershadowHeight: CGFloat {
        ceil(radius * 2.5) + y
    }
}

/// 用于「承接」上方工具栏底部阴影的视图扩展。
///
/// `AppToolbarContainer` 通过 `.shadow()` 把阴影绘制在自身边界之外。
/// 当正下方是一个背景完全不透明的视图时（例如编辑器面板），
/// 这些阴影像素会落在不透明背景的绘制区域内，从而被整片覆盖、完全不可见。
///
/// 在这类不透明接收视图上调用 `.appToolbarUndershadow(.xxxl)`，
/// 用一条从 `level.color` 衰减到透明的渐变盖在顶部，模拟出等价的阴影外观。
/// 渐变是真正带 alpha 的内容，且画在 overlay 最上层，不会被下方背景覆盖。
public extension View {
    func appToolbarUndershadow(_ level: AppShadowLevel) -> some View {
        modifier(AppToolbarUndershadowModifier(level: level))
    }
}

private struct AppToolbarUndershadowModifier: ViewModifier {
    let level: AppShadowLevel

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // 自上而下：阴影色 → 透明，模拟顶部工具栏投下的阴影衰减。
            LinearGradient(
                colors: [level.color, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: level.undershadowHeight)
            .allowsHitTesting(false)
        }
    }
}

/// 统一的工具栏容器组件
///
/// 提供标准化的水平工具栏样式，包含统一的高度、背景、底部 border 和可选的底部 shadow。
/// 用于 AppTitleToolbar、HeaderView、RailView、Breadcrumb 等场景。
public struct AppToolbarContainer<Content: View>: View {
    @LumiTheme private var theme

    let height: CGFloat
    let showsBottomBorder: Bool
    let bottomShadowLevel: AppShadowLevel
    let backgroundStyle: AppSurfaceStyle
    let padding: EdgeInsets
    let content: () -> Content

    public init(
        height: CGFloat = 40,
        showsBottomBorder: Bool = true,
        bottomShadowLevel: AppShadowLevel = .none,
        backgroundStyle: AppSurfaceStyle = .toolbar,
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.height = height
        self.showsBottomBorder = showsBottomBorder
        self.bottomShadowLevel = bottomShadowLevel
        self.backgroundStyle = backgroundStyle
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .appSurface(style: backgroundStyle, cornerRadius: 0)
            .overlay(alignment: .bottom) {
                if showsBottomBorder {
                    AppDivider()
                }
            }
            .compositingGroup()
            .shadow(color: bottomShadowLevel.color, radius: bottomShadowLevel.radius, y: bottomShadowLevel.y)
    }
}

#Preview("不同阴影级别") {
    VStack(spacing: 16) {
        AppToolbarContainer(bottomShadowLevel: .xs) { Text("xs") }
        AppToolbarContainer(bottomShadowLevel: .sm) { Text("sm") }
        AppToolbarContainer(bottomShadowLevel: .md) { Text("md") }
        AppToolbarContainer(bottomShadowLevel: .lg) { Text("lg") }
        AppToolbarContainer(bottomShadowLevel: .xl) { Text("xl") }
        AppToolbarContainer(bottomShadowLevel: .xxl) { Text("xxl") }
        AppToolbarContainer(bottomShadowLevel: .xxxl) { Text("xxxl") }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
