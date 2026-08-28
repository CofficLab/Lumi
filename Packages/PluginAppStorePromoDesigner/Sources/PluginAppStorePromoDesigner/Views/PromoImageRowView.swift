import KitAppStorePromo
import LumiUI
import SwiftUI

/// Rail 中的单个图像行：点击选中，context menu 提供删除。
struct PromoImageRowView: View {
    @ObservedObject var workspace: WorkspaceStore
    @LumiTheme private var theme
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
        // 菜单挂在 row 上：放进 AppListRow 的 Button label 会被按钮吞掉右键事件。
        AppListRow(isSelected: isSelected, action: {
            workspace.selectScope(scope, taskID: task.id, imageID: image.id)
        }) {
            HStack(spacing: 8) {
                Text("\(image.order + 1)")
                    .font(.appMonoMicro)
                    .foregroundStyle(theme.textTertiary)
                Text(image.title)
                    .font(.appMicroEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
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
}

// MARK: - 预览

#Preview {
    let task = AppStorePromoTask(
        id: "preview",
        title: PromoLocalization.string("Launch Campaign"),
        appName: "Demo",
        deviceFamily: .iphone,
        images: [
            AppStorePromoImage(id: "01", title: PromoLocalization.string("Hero"), order: 0),
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