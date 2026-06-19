import SwiftUI

/// 与编辑器面包屑导航栏一致的次级工具栏容器。
public struct AppBreadcrumbBarContainer<Content: View>: View {
    @LumiTheme private var theme

    let contentHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let content: () -> Content

    public init(
        contentHeight: CGFloat = AppPanelChromeMetrics.breadcrumbContentHeight,
        horizontalPadding: CGFloat = AppPanelChromeMetrics.breadcrumbHorizontalPadding,
        verticalPadding: CGFloat = AppPanelChromeMetrics.breadcrumbVerticalPadding,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.contentHeight = contentHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content
    }

    public var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: contentHeight, alignment: .center)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(height: AppPanelChromeMetrics.breadcrumbBarHeight, alignment: .center)
            .background(theme.textTertiary.opacity(0.035))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.textTertiary.opacity(0.08))
                    .frame(height: 1)
            }
    }
}
