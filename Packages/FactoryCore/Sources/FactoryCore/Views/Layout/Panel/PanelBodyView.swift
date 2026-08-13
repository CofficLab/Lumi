import KernelLumi
import LumiUI
import SwiftUI

/// 面板正文视图
struct PanelBodyView: View {
    private let layoutManager: WorkspaceProviding

    @LumiTheme private var theme

    init(layoutManager: WorkspaceProviding) {
        self.layoutManager = layoutManager
    }

    var body: some View {
        let container = layoutManager.currentViewContainer

        if layoutManager.isPanelBodyVisible {
            Group {
                if let container, let makeView = container.makeView {
                    makeView()
                        .id(container.id)
                        .frame(maxWidth: .infinity)
                } else {
                    ZStack {
                        theme.surface
                        AppEmptyState(
                            icon: "rectangle.center.inset.filled",
                            title: "No content"
                        )
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
