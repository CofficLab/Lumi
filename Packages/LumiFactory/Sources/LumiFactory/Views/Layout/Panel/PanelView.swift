import LumiKernel
import LumiUI
import SwiftUI

/// 面板视图，显示容器内容和底部面板
///
/// 只负责组合 Header / Body / Bottom 三个子视图。
struct PanelView: View {
    @ObservedObject var kernel: LumiKernel
    private let layoutManager: WorkspaceProviding

    @State private var isPanelHeaderVisible: Bool = true
    @State private var isPanelBodyVisible: Bool = true
    @State private var isPanelBottomVisible: Bool = true

    init(kernel: LumiKernel, layoutManager: WorkspaceProviding) {
        self.kernel = kernel
        self.layoutManager = layoutManager
    }

    var body: some View {
        Group {
            if isPanelHeaderVisible || isPanelBodyVisible || isPanelBottomVisible {
                VStack {
                    if isPanelHeaderVisible {
                        PanelHeaderView(layoutManager: layoutManager)
                            .frame(maxWidth: .infinity)
                    }
                    
                    VSplitView {
                        if isPanelBodyVisible {
                            PanelBodyView(layoutManager: layoutManager)
                                .frame(maxWidth: .infinity)
                                .id(self.layoutManager.activeViewContainerID)
                                .appSplitDivider(.bottom)
                        }
                        PanelBottomView(layoutManager: layoutManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            syncVisibilityState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)) { _ in
            syncVisibilityState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bottomPanelVisibleDidChange)) { notification in
            if let visible = notification.userInfo?["visible"] as? Bool {
                isPanelBottomVisible = visible
            }
        }
    }

    private func syncVisibilityState() {
        isPanelHeaderVisible = layoutManager.isPanelHeaderVisible
        isPanelBodyVisible = layoutManager.isPanelBodyVisible
        isPanelBottomVisible = layoutManager.isPanelBottomVisible
    }
}
