import AppStorePromoKit
import SwiftUI

/// Rail 中的任务节点：可展开展示其下所有图像，点击标题选中任务。
struct PromoTaskTreeView: View {
    @ObservedObject var workspace: WorkspaceStore
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
                    .padding(.vertical, 5)
            } else {
                ForEach(task.images.sorted(by: { $0.order < $1.order })) { image in
                    PromoImageRowView(
                        workspace: workspace,
                        scope: scope,
                        task: task,
                        image: image
                    )
                }
            }
        } label: {
            taskHeader
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var taskHeader: some View {
        Button {
            workspace.selectScope(
                scope,
                taskID: task.id,
                imageID: task.images.sorted(by: { $0.order < $1.order }).first?.id
            )
            isExpanded = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(task.images.count) \(PromoLocalization.string("images")) · \(task.deviceFamily.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.trailing, 6)
            .contentShape(Rectangle())
            .background(highlightBackground)
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
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