import LumiKernel
import LumiUI
import SwiftUI

struct PanelWorkspaceView: View {
    @LumiTheme private var theme

    let container: LumiViewContainerItem?
    let headerItems: [LumiPanelHeaderItem]
    let bottomTabs: [LumiPanelBottomTabItem]
    let viewContainerID: String

    @ObservedObject var layoutState: LayoutState

    /// 是否有任何底部 panel tab
    private var hasBottomTabs: Bool {
        !bottomTabs.isEmpty
    }

    /// 头部面板是否可见（由 WorkspaceState 控制）
    private var showsHeader: Bool {
        // header 跟随 panel chrome 状态
        layoutState.bottomPanelVisible && hasBottomTabs
    }

    init(
        container: LumiViewContainerItem?,
        headerItems: [LumiPanelHeaderItem],
        bottomTabs: [LumiPanelBottomTabItem],
        viewContainerID: String,
        layoutState: LayoutState
    ) {
        self.container = container
        self.headerItems = headerItems
        self.bottomTabs = bottomTabs
        self.viewContainerID = viewContainerID
        self.layoutState = layoutState
    }

    private var showBottomPanel: Bool {
        hasBottomTabs && layoutState.bottomPanelVisible
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
                .background(
                    SplitViewDividerPersistence.bottomPanel(
                        layoutState: layoutState,
                        viewContainerID: viewContainerID
                    )
                )
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
                if showsHeader, !headerItems.isEmpty {
                    PanelHeaderView(items: headerItems)
                }
                PanelBodyView(container: container)
            }
        } else {
            PanelBodyView(container: nil)
        }
    }
}