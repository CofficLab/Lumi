import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelWorkspaceView: View {
    @LumiTheme private var theme

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
        if let container {
            VStack(spacing: 0) {
                if showsPanelChrome, !headerItems.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(headerItems) { item in
                            item.makeView()
                                .id(item.id)
                            AppDivider()
                        }
                    }
                }

                container.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(container.id)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            theme.surface

            AppEmptyState(
                icon: "rectangle.center.inset.filled",
                title: "No content"
            )
            .padding(24)
        }
    }
}
