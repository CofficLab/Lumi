import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// The main panel column that contains Rail and Panel Workspace
struct PanelColumnView: View {
    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let showsPanelChrome: Bool
    let showRail: Bool
    let railTabs: [LumiPanelRailTabItem]
    @ObservedObject var layoutState: PanelLayoutState
    let editor: any LumiEditorServicing

    private var viewContainerID: String {
        container?.id ?? "main"
    }

    private var railStorageKey: String {
        LayoutStorageKey.railWidth(viewContainerID: viewContainerID)
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
                    showsPanelChrome: showsPanelChrome,
                    viewContainerID: viewContainerID, layoutState: layoutState
                )
            }
        }

        if showsPanelChrome {
            EditorScopeView(editor: editor) {
                column
            }
            .modifier(PanelChromeCommandHandler(layoutState: layoutState))
        } else {
            column
        }
    }

    @ViewBuilder
    private var railWithPanel: some View {
        if showsPanelChrome {
            HSplitView {
                RailView(tabs: railTabs, layoutState: layoutState)
                    .background(
                        SplitViewWidthPersistence(storageKey: railStorageKey)
                    )
                PanelWorkspaceView(
                    container: container,
                    headerItems: headerItems,
                    bottomTabs: bottomTabs,
                    showsPanelChrome: showsPanelChrome,
                    viewContainerID: viewContainerID, layoutState: layoutState
                )
            }
            .id(viewContainerID)
        } else {
            RailView(tabs: railTabs, layoutState: layoutState)
                .background(
                    SplitViewWidthPersistence(storageKey: railStorageKey)
                )
                .id(viewContainerID)
        }
    }
}
