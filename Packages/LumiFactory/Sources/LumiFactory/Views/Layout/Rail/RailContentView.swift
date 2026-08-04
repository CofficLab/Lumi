import LumiKernel
import SwiftUI

// MARK: - Rail Content View

struct RailContentView: View {
    @ObservedObject var kernel: LumiKernel

    private var tabs: [PanelRailTabItem] {
        guard let workspace = kernel.workspace else { return [] }
        let containerID = workspace.activeViewContainerID ?? ""
        let supportsProject = workspace.currentViewContainer?.supportsProject == true
        return workspace.allPanelRailTabItems.filter {
            $0.visibility.isVisible(in: containerID)
                && (!$0.requiresProjectSupport || supportsProject)
        }
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
