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

    /// 匹配当前激活的容器，匹配不到则显示空状态。
    private var container: ViewContainerItem? {
        kernel.layoutManager?.allViewContainers.first { $0.id == viewContainerID }
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
