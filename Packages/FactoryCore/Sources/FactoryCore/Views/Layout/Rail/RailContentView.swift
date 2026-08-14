import KernelLumi
import SwiftUI

// MARK: - Rail Content View

struct RailContentView: View {
    @ObservedObject var kernel: KernelLumi

    private var tabs: [PanelRailTabItem] {
        guard let workspace = kernel.workspace else { return [] }
        let containerID = workspace.activeViewContainerID ?? ""
        let container = workspace.currentViewContainer
        let supportsProject = container?.supportsProject == true
        let supportsChat = container?.chatVisibility.isSupported == true
        return filteredRailTabs(
            workspace.allPanelRailTabItems,
            containerID: containerID,
            supportsProject: supportsProject,
            supportsChat: supportsChat
        )
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
