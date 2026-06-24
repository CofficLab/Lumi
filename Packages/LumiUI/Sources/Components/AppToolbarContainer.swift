import SwiftUI

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
    let showsBottomShadow: Bool
    let backgroundStyle: AppSurfaceStyle
    let padding: EdgeInsets
    let content: () -> Content

    /// 创建工具栏容器
    /// - Parameters:
    ///   - height: 工具栏高度，默认 40
    ///   - showsBottomBorder: 是否显示底部 border，默认 true
    ///   - showsBottomShadow: 是否显示底部 shadow，默认 false
    ///   - backgroundStyle: 背景样式，默认 .toolbar
    ///   - padding: 内边距，默认 horizontal: 8, vertical: 4
    ///   - content: 工具栏内容
    public init(
        height: CGFloat = 40,
        showsBottomBorder: Bool = true,
        showsBottomShadow: Bool = false,
        backgroundStyle: AppSurfaceStyle = .toolbar,
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.height = height
        self.showsBottomBorder = showsBottomBorder
        self.showsBottomShadow = showsBottomShadow
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
            .shadow(color: showsBottomShadow ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
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
