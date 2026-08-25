import KitAppStorePromo
import LumiUI
import SwiftUI

/// Rail 中的任务节点：可展开展示其下所有图像，点击标题选中任务。
struct PromoTaskTreeView: View {
    @ObservedObject var workspace: WorkspaceStore
    @LumiTheme private var theme
    @Binding var isExpanded: Bool
    let scope: Scope
    let task: AppStorePromoTask

    // MARK: - 初始化

    init(
        workspace: WorkspaceStore,
        isExpanded: Binding<Bool>,
        scope: Scope,
        task: AppStorePromoTask
    ) {
        self.workspace = workspace
        self._isExpanded = isExpanded
        self.scope = scope
        self.task = task
    }

    // MARK: - Body

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if task.images.isEmpty {
                Text(PromoLocalization.string("No images yet"))
                    .font(.footnote)
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
            } else {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(task.images.sorted(by: { $0.order < $1.order })) { image in
                        PromoImageRowView(
                            workspace: workspace,
                            scope: scope,
                            task: task,
                            image: image
                        )
                    }
                }
                .padding(.leading, DesignTokens.Spacing.sm)
            }
        } label: {
            taskHeader
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var taskHeader: some View {
        // 点选任务即选中（并自动展开）；展开/折叠交给 DisclosureGroup 原生三角。
        // 菜单挂在 row 上，避免被 AppListRow 的 Button 吞掉右键事件。
        AppListRow(isSelected: isSelected, action: {
            workspace.selectScope(
                scope,
                taskID: task.id,
                imageID: task.images.sorted(by: { $0.order < $1.order }).first?.id
            )
            isExpanded = true
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "rectangle.stack")
                    .foregroundStyle(theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text("\(task.images.count) \(PromoLocalization.string("images")) · \(task.deviceFamily.rawValue)")
                        .font(.footnote)
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteTask(scope: scope, id: task.id)
            } label: {
                Label(PromoLocalization.string("Delete Task"), systemImage: "trash")
            }
        }
    }

    // MARK: - 计算属性

    private var isSelected: Bool {
        workspace.selectedScope == scope && workspace.selectedTaskID == task.id
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
            AppStorePromoImage(id: "02", title: "Detail", order: 1),
        ]
    )
    StatefulPreviewWrapper(true) { binding in
        PromoTaskTreeView(
            workspace: WorkspaceStore.shared,
            isExpanded: binding,
            scope: .project,
            task: task
        )
    }
    .frame(width: 300)
    .background(Color(nsColor: .controlBackgroundColor))
}

/// 仅用于预览：为绑定提供可写状态。
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initialValue)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}