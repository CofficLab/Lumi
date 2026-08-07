import LumiKernel
import SwiftUI

/// Toolbar title view that only displays when this plugin's container is active.
struct ImageToPDFToolbarTitleView: View {
    let containerID: String
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var workspaceBox = ObservableWorkspaceBox()

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // 条件依赖 workspaceBox.service（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
        Group {
            if workspaceBox.service?.activeViewContainerID == containerID {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(ImageToPDFLocalization.string("Image to PDF"))
                        .font(.headline)
                }
            }
        }
        .task { workspaceBox.bind(kernel.workspace) }
    }
}
