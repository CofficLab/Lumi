import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelWorkspaceView: View {
    @LumiTheme private var theme
    
    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let showsPanelChrome: Bool
    let viewContainerID: String

    @ObservedObject private var globalLayoutState = LumiLayoutStateStore.shared
    @ObservedObject var layoutState: PanelLayoutState

    private var showBottomPanel: Bool {
        showsPanelChrome && !bottomTabs.isEmpty && globalLayoutState.bottomPanelVisible
    }

    var body: some View {
        Group {
            if showBottomPanel {
                VSplitView {
                    contentPanel
                        .layoutPriority(1)
                    PanelBottomView(
                        tabs: bottomTabs,
                        layoutState: layoutState,
                        viewContainerID: viewContainerID
                    )
                }
            } else {
                contentPanel
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
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
        } else {
            PanelBodyView(container: nil)
        }
    }
}
