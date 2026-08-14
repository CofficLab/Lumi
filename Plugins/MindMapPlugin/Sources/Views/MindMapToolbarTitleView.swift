import KernelLumi
import SwiftUI

/// 标题栏：显示插件名 + 当前选中思维导图标题与节点数。
struct MindMapToolbarTitleView: View {
    let containerID: String
    let kernel: KernelLumi
    let title: String

    @ObservedObject private var store = MindMapStore.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
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
