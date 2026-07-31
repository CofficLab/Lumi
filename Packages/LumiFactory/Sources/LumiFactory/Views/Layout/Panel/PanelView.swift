import LumiKernel
import LumiUI
import SwiftUI

/// 面板视图，显示容器内容和底部面板
///
/// 只负责组合 Header / Body / Bottom 三个子视图，并应用底部 divider 持久化。
struct PanelView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var layoutManager: LayoutProviding? {
        kernel.layoutManager
    }

    private var isPanelVisible: Bool {
        layoutManager?.isPanelVisible ?? true
    }

    private var viewContainerID: String {
        layoutManager?.activeViewContainerID ?? ""
    }

    private var layoutState: LayoutState {
        layoutManager?.layoutState ?? LayoutState()
    }

    var body: some View {
        Group {
            if layoutManager == nil {
                ErrorView(error: LumiKernelError.serviceNotAvailable(service: "LayoutManager"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isPanelVisible {
                VSplitView {
                    if layoutState.isPanelHeaderVisible {
                        PanelHeaderView(kernel: kernel)
                            .frame(maxWidth: .infinity)
                    }
                    PanelBodyView(kernel: kernel)
                        .frame(maxWidth: .infinity)
                    if layoutState.isPanelBottomVisible {
                        PanelBottomView(kernel: kernel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    SplitViewDividerPersistence.bottomPanel(
                        layoutState: layoutState,
                        viewContainerID: viewContainerID
                    )
                )
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
