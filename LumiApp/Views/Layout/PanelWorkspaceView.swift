import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelWorkspaceView: View {
    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let showsPanelChrome: Bool
    @ObservedObject var layoutState: PanelLayoutState

    private var showBottomPanel: Bool {
        showsPanelChrome && !bottomTabs.isEmpty
    }

    var body: some View {
        Group {
            if showBottomPanel {
                VSplitView {
                    contentPanel
                        .layoutPriority(1)
                    PanelBottomView(tabs: bottomTabs, layoutState: layoutState)
                }
            } else {
                contentPanel
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    @ViewBuilder
    private var contentPanel: some View {
        if container != nil {
            VStack(spacing: 0) {
                if showsPanelChrome, !headerItems.isEmpty {
                    PanelHeaderView(items: headerItems)
                }
                PanelBodyView(container: container)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PanelBodyView(container: nil)
        }
    }
}
