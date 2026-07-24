import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// The main panel column that contains Rail and Panel Workspace
struct PanelColumnView: View {
    @ObservedObject var kernel: LumiKernel

    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let editor: any LumiEditorServicing

    private var viewContainerID: String {
        container?.id ?? "main"
    }

    private var showRail: Bool {
        kernel.layout?.isRailVisible ?? true
    }

    var body: some View {
        let column = Group {
            if showRail {
                railWithPanel
            } else {
                PanelView(
                    container: container,
                    headerItems: headerItems,
                    bottomTabs: bottomTabs,
                    viewContainerID: viewContainerID,
                    layoutState: kernel.layout?.layoutState ?? LayoutState()
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
        HSplitView {
            RailView(kernel: kernel)
            PanelView(
                container: container,
                headerItems: headerItems,
                bottomTabs: bottomTabs,
                viewContainerID: viewContainerID,
                layoutState: kernel.layout?.layoutState ?? LayoutState()
            )
        }
        .id(viewContainerID)
        .background(SplitViewDividerPersistence.rail(layoutState: kernel.layout?.layoutState ?? LayoutState(), viewContainerID: viewContainerID))
    }
}
