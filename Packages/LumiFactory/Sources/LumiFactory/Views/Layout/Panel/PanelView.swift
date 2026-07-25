import LumiKernel
import LumiUI
import SwiftUI

/// 面板视图，显示容器内容和底部面板
///
/// 只负责组合 Header / Body / Bottom 三个子视图，并应用底部 divider 持久化。
struct PanelView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var isPanelVisible: Bool {
        kernel.layoutManager?.isPanelVisible ?? true
    }

    private var viewContainerID: String {
        kernel.layoutManager?.activeViewContainerID ?? "main"
    }

    private var layoutState: LayoutState {
        kernel.layoutManager?.layoutState ?? LayoutState()
    }

    var body: some View {
        Group {
            if isPanelVisible {
                VSplitView {
                    PanelHeaderView(kernel: kernel)
                        .frame(maxWidth: .infinity)
                    PanelBodyView(kernel: kernel)
                        .frame(maxWidth: .infinity)
                    PanelBottomView(kernel: kernel)
                        .frame(maxWidth: .infinity)
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
