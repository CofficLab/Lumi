import SwiftUI

/// 项目分类头部视图
struct ProjectSectionHeader: View {
    let project: ProjectInfo

    var body: some View {
        HStack {
            Image(systemName: project.type.icon)
                .foregroundColor(AppUI.Color.semantic.info)
            Text(project.name)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textPrimary)
            Spacer()
            Text(project.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppUI.Color.semantic.textTertiary.opacity(0.2))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .clipShape(Capsule())
        }
    }
}

/// 项目文件行视图
struct ProjectItemRow: View {
    let item: CleanableItem
    @ObservedObject var viewModel: ProjectCleanerViewModel

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { viewModel.selectedItemIds.contains(item.id) },
                set: { _ in viewModel.toggleSelection(item.id) }
            ))
            .labelsHidden()

            Image(systemName: "folder.fill")
                .foregroundColor(AppUI.Color.semantic.warning)

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(item.path)
                    .font(.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.body)())
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        Section(header: ProjectSectionHeader(project: ProjectInfo(
            name: "MyApp",
            path: "/Users/user/Code/MyApp",
            type: .node,
            cleanableItems: [
                CleanableItem(path: "/Users/user/Code/MyApp/node_modules", name: "node_modules", size: 1024 * 1024 * 500)
            ]
        ))) {
            ProjectItemRow(
                item: CleanableItem(path: "/Users/user/Code/MyApp/node_modules", name: "node_modules", size: 1024 * 1024 * 500),
                viewModel: ProjectCleanerViewModel()
            )
        }
    }
    .listStyle(.inset)
}
