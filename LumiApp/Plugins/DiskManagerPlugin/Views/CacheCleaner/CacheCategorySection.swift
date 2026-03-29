import SwiftUI

/// 缓存分类列表节视图
struct CacheCategorySection: View {
    let category: CacheCategory
    @ObservedObject var viewModel: CacheCleanerViewModel
    @State private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(category.paths) { path in
                CachePathRow(path: path, isSelected: viewModel.selection.contains(path.id)) {
                    viewModel.toggleSelection(for: path)
                }
            }
        } header: {
            HStack {
                Image(systemName: category.icon)
                Text(category.name)
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer()

                // Safety Badge
                Text(category.safetyLevel.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppUI.Color.semantic.warning.opacity(0.2))
                    .foregroundColor(AppUI.Color.semantic.warning)
                    .cornerRadius(4)

                Text(viewModel.formatBytes(category.totalSize))
                    .font(.monospacedDigit(.caption)())
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
}

/// 缓存路径行视图
struct CachePathRow: View {
    let path: CachePath
    let isSelected: Bool
    let toggleAction: () -> Void

    // 在 UI 层计算图标（避免在 Sendable 模型中存储 NSImage）
    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path.path)
    }

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in toggleAction() }))
                .labelsHidden()

            AppImageThumbnail(
                image: Image(nsImage: icon),
                size: CGSize(width: 24, height: 24),
                shape: .none
            )

            VStack(alignment: .leading) {
                Text(path.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                Text(path.path)
                    .font(.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(formatBytes(path.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
