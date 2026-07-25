import LumiKernel
import SwiftUI

// MARK: - Rail Content View

struct RailContentView: View {
    @ObservedObject var kernel: LumiKernel

    private var tabs: [PanelRailTabItem] {
        kernel.sharedUI?.allPanelRailTabItems ?? []
    }

    private var activeTabID: String {
        kernel.layoutManager?.activeRailTabID ?? ""
    }

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
