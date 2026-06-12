import SwiftUI

/// 项目分类头部视图
struct ProjectSectionHeader: View {
    let project: ProjectInfo

    var body: some View {
        HStack {
            Image(systemName: project.type.icon)
                .foregroundColor(Color(hex: "0A84FF"))
            Text(project.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            Spacer()
            Text(project.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "98989E").opacity(0.2))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                .foregroundColor(Color(hex: "FF9F0A"))

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(item.path)
                    .font(.caption2)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.body)())
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.vertical, 4)
    }
}

