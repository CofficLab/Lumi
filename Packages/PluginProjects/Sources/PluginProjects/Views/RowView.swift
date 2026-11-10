import LumiUI
import SwiftUI

struct RowView: View {
    let project: ProjectEntry
    let isSelected: Bool
    let select: () -> Void
    let remove: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: select) {
            HStack(spacing: 10) {
                ProjectStorageIcon(
                    kind: ProjectStorageDetector.kind(for: project.path),
                    size: 13,
                    tint: isSelected ? Color.accentColor : Color.secondary
                )
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    .help(storageHint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                }

                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pluginLocalization.string("Remove Project"))
            }
        }
    }

    /// 存储状态提示；仅在项目不可用时给出说明。
    private var storageHint: String {
        ProjectStorageHint.text(for: ProjectStorageDetector.kind(for: project.path))
    }
}
