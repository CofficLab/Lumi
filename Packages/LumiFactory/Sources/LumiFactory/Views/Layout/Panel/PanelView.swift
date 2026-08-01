import LumiKernel
import LumiUI
import SwiftUI

/// 面板视图，显示容器内容和底部面板
///
/// 只负责组合 Header / Body / Bottom 三个子视图。
struct PanelView: View {
    @ObservedObject var kernel: LumiKernel
    private let layoutManager: WorkspaceProviding

    init(kernel: LumiKernel, layoutManager: WorkspaceProviding) {
        self.kernel = kernel
        self.layoutManager = layoutManager
    }

    var body: some View {
        if self.layoutManager.isPanelHeaderVisible || self.layoutManager.isPanelBodyVisible || self.layoutManager.isPanelBottomVisible {
            VSplitView {
                PanelHeaderView(layoutManager: layoutManager)
                    .frame(maxWidth: .infinity)
                PanelBodyView(layoutManager: layoutManager)
                    .frame(maxWidth: .infinity)
                    .id(self.layoutManager.activeViewContainerID)
                PanelBottomView(layoutManager: layoutManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
