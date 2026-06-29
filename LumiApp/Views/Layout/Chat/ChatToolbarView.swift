import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatToolbarView: View {
    @LumiTheme private var theme

    let items: [LumiChatSectionToolbarBarItem]

    var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            showsBottomBorder: true,
            backgroundStyle: .panel,
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)

                ForEach(items) { item in
                    item.makeView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
        }
        .shadowMd()
    }
}
