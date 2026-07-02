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

    @ObservedObject private var globalLayoutState: LumiLayoutState
    @ObservedObject var layoutState: PanelLayoutState

    init(
        container: LumiViewContainerItem?,
        headerItems: [LumiPanelHeaderItem],
        bottomTabs: [LumiPanelBottomTabItem],
        showsPanelChrome: Bool,
        viewContainerID: String,
        layoutState: PanelLayoutState
    ) {
        self.container = container
        self.headerItems = headerItems
        self.bottomTabs = bottomTabs
        self.showsPanelChrome = showsPanelChrome
        self.viewContainerID = viewContainerID
        self.layoutState = layoutState
        _globalLayoutState = ObservedObject(initialValue: LumiCore.layoutState ?? LumiLayoutState())
    }

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
