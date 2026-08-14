import KernelLumi
import LumiUI
import SwiftUI

/// Toolbar title view that only displays when this plugin's container is active.
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次当前 activeViewContainerID，
/// 监听 `.activeViewContainerIDDidChange` 事件更新。
struct ImageToPDFToolbarTitleView: View {
    let containerID: String
    let kernel: KernelLumi

    @State private var activeContainerID: String?

    init(containerID: String, kernel: KernelLumi) {
        self.containerID = containerID
        self.kernel = kernel
        _activeContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        Group {
            if activeContainerID == containerID {
                AppToolbarTitleLabel(
                    icon: "photo.on.rectangle.angled",
                    title: ImageToPDFLocalization.string("Image to PDF")
                )
            }
        }
        .onActiveViewContainerIDDidChange { newContainerID in
            activeContainerID = newContainerID
        }
    }
}
