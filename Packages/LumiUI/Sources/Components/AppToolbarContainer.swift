import SwiftUI

/// 统一的工具栏容器组件
///
/// 提供标准化的水平工具栏样式，包含统一的高度和背景。
/// 用于 AppTitleToolbar、HeaderView、RailView、Breadcrumb 等场景。
public struct AppToolbarContainer<Content: View>: View {
    @LumiTheme private var theme

    let height: CGFloat
    let backgroundStyle: AppSurfaceStyle
    let padding: EdgeInsets
    let content: () -> Content

    public init(
        height: CGFloat = 40,
        backgroundStyle: AppSurfaceStyle = .toolbar,
        padding: EdgeInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.height = height
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
            .compositingGroup()
    }
}

#Preview("不同阴影和边框组合") {
    VStack(spacing: 16) {
        AppToolbarContainer { Text("无装饰") }
        
        AppToolbarContainer { Text("仅边框") }
            .borderBottom()
        
        AppToolbarContainer { Text("仅阴影 sm") }
            .shadowSm()
        
        AppToolbarContainer { Text("边框 + 阴影 md") }
            .borderBottom()
            .shadowMd()
        
        AppToolbarContainer { Text("边框 + 阴影 lg") }
            .borderBottom()
            .shadowLg()
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
