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
}

/// 统一的工具栏容器组件
///
/// 提供标准化的水平工具栏样式，包含统一的高度、背景、底部 border 和可选的底部 shadow。
/// 用于 AppTitleToolbar、HeaderView、RailView、Breadcrumb 等场景。
///
/// ## 示例
/// ```swift
/// AppToolbarContainer {
///     HStack(spacing: 8) {
///         // 工具栏内容
///     }
/// }
/// ```
public struct AppToolbarContainer<Content: View>: View {
    @LumiTheme private var theme

    let height: CGFloat
    let showsBottomBorder: Bool
    let bottomShadowLevel: AppShadowLevel
    let backgroundStyle: AppSurfaceStyle
    let padding: EdgeInsets
    let content: () -> Content

    /// 创建工具栏容器
    /// - Parameters:
    ///   - height: 工具栏高度，默认 40
    ///   - showsBottomBorder: 是否显示底部 border，默认 true
    ///   - bottomShadowLevel: 底部阴影级别，默认 .none
    ///   - backgroundStyle: 背景样式，默认 .toolbar
    ///   - padding: 内边距，默认 horizontal: 8, vertical: 4
    ///   - content: 工具栏内容
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
            .shadow(color: bottomShadowLevel.color, radius: bottomShadowLevel.radius, y: bottomShadowLevel.y)
    }
}

#Preview("基础样式") {
    VStack(spacing: 0) {
        AppToolbarContainer {
            HStack {
                Image(systemName: "folder")
                Text("文件浏览器")
                Spacer()
                Image(systemName: "plus")
            }
        }

        Color.gray.opacity(0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("无底部 border") {
    VStack(spacing: 0) {
        AppToolbarContainer(showsBottomBorder: false) {
            HStack {
                Image(systemName: "gear")
                Text("设置")
                Spacer()
            }
        }

        Color.gray.opacity(0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("不同背景样式") {
    VStack(spacing: 12) {
        AppToolbarContainer(backgroundStyle: .toolbar) {
            HStack {
                Image(systemName: "hammer")
                Text("工具栏样式")
            }
        }

        AppToolbarContainer(backgroundStyle: .panel) {
            HStack {
                Image(systemName: "square.stack")
                Text("面板样式")
            }
        }

        AppToolbarContainer(backgroundStyle: .subtle) {
            HStack {
                Image(systemName: "circle")
                Text("柔和样式")
            }
        }
    }
    .padding()
}

#Preview("不同阴影级别") {
    VStack(spacing: 16) {
        AppToolbarContainer(bottomShadowLevel: .xs) {
            Text("xs")
        }

        AppToolbarContainer(bottomShadowLevel: .sm) {
            Text("sm")
        }

        AppToolbarContainer(bottomShadowLevel: .md) {
            Text("md")
        }

        AppToolbarContainer(bottomShadowLevel: .lg) {
            Text("lg")
        }

        AppToolbarContainer(bottomShadowLevel: .xl) {
            Text("xl")
        }

        AppToolbarContainer(bottomShadowLevel: .xxl) {
            Text("xxl")
        }

        AppToolbarContainer(bottomShadowLevel: .xxxl) {
            Text("xxxl")
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
