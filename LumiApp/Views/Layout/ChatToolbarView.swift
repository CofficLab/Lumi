import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatToolbarView: View {
    let items: [LumiChatSectionToolbarBarItem]

    var body: some View {
        AppBreadcrumbBarContainer(showsBottomShadow: true) {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)

                ForEach(items) { item in
                    item.makeView()
                }
            }
        }
        .frame(height: AppPanelChromeMetrics.breadcrumbBarHeight)
    }
}
