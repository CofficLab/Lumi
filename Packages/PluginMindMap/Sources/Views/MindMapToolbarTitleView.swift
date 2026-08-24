import KernelLumi
import LumiUI
import SwiftUI

/// 标题栏：显示插件名 + 当前选中思维导图标题与节点数。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次当前 `activeViewContainerID`，
/// 监听 `.activeViewContainerIDDidChange` 事件更新，
/// 避免切换容器后在其它容器中残留标题。
struct MindMapToolbarTitleView: View {
    let containerID: String
    let kernel: KernelLumi
    let title: String

    @ObservedObject private var store = MindMapStore.shared
    @State private var activeContainerID: String?

    init(containerID: String, kernel: KernelLumi, title: String) {
        self.containerID = containerID
        self.kernel = kernel
        self.title = title
        _activeContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        Group {
            if activeContainerID == containerID {
                AppToolbarTitleLabel(icon: "brain.head.profile", title: title) {
                    if let map = store.selectedMap {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(map.title)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Text("(\(map.nodes.count))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .onActiveViewContainerIDDidChange { newContainerID in
            activeContainerID = newContainerID
        }
    }
}
