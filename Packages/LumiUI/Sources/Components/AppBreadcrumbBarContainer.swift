import SwiftUI

/// 面包屑导航栏容器。
///
/// 底层复用 `AppToolbarContainer`，提供与编辑器面包屑一致的淡灰背景和底部 border。
/// 支持可选的底部 shadow。
public struct AppBreadcrumbBarContainer<Content: View>: View {
    @LumiTheme private var theme

    let showsBottomShadow: Bool
    let content: () -> Content

    public init(
        showsBottomShadow: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsBottomShadow = showsBottomShadow
        self.content = content
    }

    public var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            showsBottomBorder: true,
            showsBottomShadow: showsBottomShadow,
            backgroundStyle: .custom(theme.textTertiary.opacity(0.035)),
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
        }
    }
}
