import SwiftUI

/// Xcode 清理分类节视图
struct XcodeCategorySection: View {
    let category: XcodeCleanCategory
    let items: [XcodeCleanItem]
    @ObservedObject var viewModel: XcodeCleanerViewModel
    @State private var isExpanded = true

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    var categorySize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        Section(header: headerView) {
            if isExpanded {
                ForEach(items) { item in
                    XcodeItemRow(item: item, viewModel: viewModel)
                }
            }
        }
    }

    var headerView: some View {
        HStack {
            Button(action: { withAnimation { isExpanded.toggle() } }, label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            })
            .buttonStyle(.plain)

            Image(systemName: category.iconName)
                .foregroundColor(AppUI.Color.semantic.info)

            VStack(alignment: .leading) {
                Text(category.displayName)
                    .font(.headline)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(category.description)
                    .font(.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }

            Spacer()

            Text(viewModel.formatBytes(categorySize))
                .font(.monospacedDigit(.body)())
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            // 全选/反选 Checkbox
            Toggle("", isOn: Binding(
                get: { selectedCount == items.count && items.count > 0 },
                set: { isSelected in
                    if isSelected {
                        viewModel.selectAll(in: category)
                    } else {
                        viewModel.deselectAll(in: category)
                    }
                }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 8)
    }
}

/// Xcode 清理项目行视图
struct XcodeItemRow: View {
    let item: XcodeCleanItem
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .padding(.leading, 24) // Indent

            VStack(alignment: .leading) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(item.path.path)
                    .font(.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in viewModel.toggleSelection(for: item) }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 4)
    }
}
