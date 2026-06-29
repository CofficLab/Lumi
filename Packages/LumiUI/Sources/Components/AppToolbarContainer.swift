import SwiftUI

/// 统一的工具栏容器组件
///
/// 提供标准化的水平工具栏样式，包含统一的高度、背景、底部 border 和可选的底部 shadow。
/// 用于 AppTitleToolbar、HeaderView、RailView、Breadcrumb 等场景。
public struct AppToolbarContainer<Content: View>: View {
    @LumiTheme private var theme

    let height: CGFloat
    let showsBottomBorder: Bool
    let backgroundStyle: AppSurfaceStyle
    let padding: EdgeInsets
    let content: () -> Content

    public init(
        height: CGFloat = 40,
        showsBottomBorder: Bool = true,
        backgroundStyle: AppSurfaceStyle = .toolbar,
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.height = height
        self.showsBottomBorder = showsBottomBorder
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
    }
}

#Preview("不同阴影级别") {
    VStack(spacing: 16) {
        AppToolbarContainer { Text("xs") }.shadowXs()
        AppToolbarContainer { Text("sm") }.shadowSm()
        AppToolbarContainer { Text("md") }.shadowMd()
        AppToolbarContainer { Text("lg") }.shadowLg()
        AppToolbarContainer { Text("xl") }.shadowXl()
        AppToolbarContainer { Text("xxl") }.shadowXxl()
        AppToolbarContainer { Text("xxxl") }.shadowXxxl()
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
