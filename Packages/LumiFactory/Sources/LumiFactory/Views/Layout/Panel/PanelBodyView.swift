import LumiKernel
import LumiUI
import SwiftUI

/// 面板正文视图
///
/// 只接收 kernel，所需数据（当前激活的 view container）由视图自身从内核读取。
struct PanelBodyView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var viewContainerID: String {
        kernel.layoutManager?.activeViewContainerID ?? "main"
    }

    /// 优先匹配当前激活的容器，否则回退到第一个。
    private var container: ViewContainerItem? {
        kernel.viewContainer?.allViewContainers.first { $0.id == viewContainerID }
            ?? kernel.viewContainer?.allViewContainers.first
    }

    var body: some View {
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
