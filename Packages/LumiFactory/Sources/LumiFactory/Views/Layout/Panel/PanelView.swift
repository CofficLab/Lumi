import LumiKernel
import LumiUI
import SwiftUI

/// 面板视图，显示容器内容和底部面板
struct PanelView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var viewContainerID: String {
        kernel.layout?.activeViewContainerID ?? "main"
    }

    private var layoutState: LayoutState {
        kernel.layout?.layoutState ?? LayoutState()
    }

    private var container: ViewContainerItem? {
        kernel.viewContainer?.allViewContainers.first { $0.id == viewContainerID }
            ?? kernel.viewContainer?.allViewContainers.first
    }

    private var headerItems: [PanelHeaderItem] {
        kernel.panel?.allPanelHeaderItems ?? []
    }

    private var bottomTabs: [PanelBottomTabItem] {
        kernel.panel?.allPanelBottomTabItems ?? []
    }

    /// 是否有任何底部 panel tab
    private var hasBottomTabs: Bool {
        !bottomTabs.isEmpty
    }

    /// 头部面板是否可见
    private var showsHeader: Bool {
        layoutState.bottomPanelVisible && hasBottomTabs
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
                        kernel: kernel,
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
