import AppStorePromoKit
import SwiftUI

/// Rail 中的单个图像行：点击选中，context menu 提供删除。
struct PromoImageRowView: View {
    @ObservedObject var workspace: WorkspaceStore
    let scope: Scope
    let task: AppStorePromoTask
    let image: AppStorePromoImage

    // MARK: - 初始化

    init(workspace: WorkspaceStore, scope: Scope, task: AppStorePromoTask, image: AppStorePromoImage) {
        self.workspace = workspace
        self.scope = scope
        self.task = task
        self.image = image
    }

    // MARK: - Body

    var body: some View {
        Button {
            workspace.selectScope(scope, taskID: task.id, imageID: image.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(image.order + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(image.title)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .padding(.vertical, 6)
            .padding(.trailing, 7)
            .background(highlightBackground)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteImage(scope: scope, taskID: task.id, imageID: image.id)
            } label: {
                Label(PromoLocalization.string("Delete Image"), systemImage: "trash")
            }
        }
    }

    // MARK: - 计算属性

    private var isSelected: Bool {
        workspace.selectedScope == scope
            && workspace.selectedTaskID == task.id
            && workspace.selectedImageID == image.id
    }

    @ViewBuilder
    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
    }
}

// MARK: - 预览

#Preview {
    let task = AppStorePromoTask(
        id: "preview",
        title: "Launch Campaign",
        appName: "Demo",
        deviceFamily: .iphone,
        images: [
            AppStorePromoImage(id: "01", title: "Hero", order: 0),
        ]
    )
    VStack(alignment: .leading) {
        PromoImageRowView(
            workspace: WorkspaceStore.shared,
            scope: .project,
            task: task,
            image: task.images[0]
        )
    }
    .frame(width: 280)
    .background(Color(nsColor: .controlBackgroundColor))
}