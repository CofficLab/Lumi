import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatHeaderView: View {
    let items: [LumiChatSectionHeaderItem]

    var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.tabBarHeight,
            padding: AppPanelChromeMetrics.tabBarPadding
        ) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    item.makeView()
                }

                Spacer(minLength: 0)
            }
        }
        .frame(height: AppPanelChromeMetrics.tabBarHeight)
    }
}
