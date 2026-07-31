import LumiKernel
import LumiUI
import SwiftUI

/// 面板正文视图
struct PanelBodyView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    var body: some View {
        if let layoutManager = kernel.layoutManager {
            contentView(layoutManager)
        } else {
            ErrorView(error: LumiKernelError.serviceNotAvailable(service: "LayoutManager"))
        }
    }

    @ViewBuilder
    private func contentView(_ layoutManager: LayoutProviding) -> some View {
        let container = layoutManager.currentViewContainer

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
