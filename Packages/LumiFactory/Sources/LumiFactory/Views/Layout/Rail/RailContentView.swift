import LumiCoreLayout
import LumiCorePanelChrome
import LumiKernel
import SwiftUI

// MARK: - Rail Content View

struct RailContentView: View {
    let tabs: [LumiPanelRailTabItem]
    let activeTabID: String

    @ViewBuilder
    var body: some View {
        if let tab = tabs.first(where: { $0.id == activeTabID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
        }
    }
}
