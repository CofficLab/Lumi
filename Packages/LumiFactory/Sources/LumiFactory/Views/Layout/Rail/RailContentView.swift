import LumiKernel
import SwiftUI

// MARK: - Rail Content View

struct RailContentView: View {
    @ObservedObject var kernel: LumiKernel

    private var tabs: [PanelRailTabItem] {
        kernel.workspace?.allPanelRailTabItems ?? []
    }

    private var viewContainerID: String {
        kernel.workspace?.activeViewContainerID ?? ""
    }

    private var activeTabID: String {
        kernel.workspace?.activeRailTabID(for: viewContainerID) ?? ""
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
