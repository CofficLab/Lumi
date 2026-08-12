import LumiKernel
import SwiftUI

/// 工具栏居中标题视图：仅在该插件对应的视图容器激活时显示。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次当前 `activeViewContainerID`，
/// 监听 `.activeViewContainerIDDidChange` 事件更新，
/// 避免切换容器后在其它容器中残留标题。
struct AppIconDesignerToolbarTitleView: View {
    let containerID: String
    let kernel: LumiKernel
    let title: String

    @State private var activeContainerID: String?

    init(containerID: String, kernel: LumiKernel, title: String) {
        self.containerID = containerID
        self.kernel = kernel
        self.title = title
        _activeContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        Group {
            if activeContainerID == containerID {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .onActiveViewContainerIDDidChange { newContainerID in
            activeContainerID = newContainerID
        }
    }
}
