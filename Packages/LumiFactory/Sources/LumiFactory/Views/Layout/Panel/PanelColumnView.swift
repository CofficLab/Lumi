import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// The main panel column that contains Rail and Panel Workspace
struct PanelColumnView: View {
    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let showRail: Bool
    let railTabs: [LumiPanelRailTabItem]
    @ObservedObject var layoutState: LayoutState
    let editor: any LumiEditorServicing

    private var viewContainerID: String {
        container?.id ?? "main"
    }

    var body: some View {
        let column = Group {
            if showRail {
                railWithPanel
            } else {
                PanelWorkspaceView(
                    container: container,
                    headerItems: headerItems,
                    bottomTabs: bottomTabs,
                    viewContainerID: viewContainerID,
                    layoutState: layoutState
                )
            }
        }

        if showRail {
            EmptyView()
        } else {
            column
        }
    }

    @ViewBuilder
    private var railWithPanel: some View {
        if true {
            HSplitView {
                RailView(tabs: railTabs, layoutState: layoutState)
                PanelWorkspaceView(
                    container: container,
                    headerItems: headerItems,
                    bottomTabs: bottomTabs,
                    viewContainerID: viewContainerID,
                    layoutState: layoutState
                )
            }
            .id(viewContainerID)
            .background(SplitViewDividerPersistence.rail(layoutState: layoutState, viewContainerID: viewContainerID))
        } else {
            RailView(tabs: railTabs, layoutState: layoutState)
                .id(viewContainerID)
        }
    }
}
