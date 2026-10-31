import LumiUI
import ProviderGit
import SwiftUI

/// 分支列表中的一行。
struct GitBranchRow: View {
    let branch: GitBranchInfo
    let isCurrent: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        AppListRow(isSelected: isCurrent, action: action) {
            HStack(spacing: 10) {
                Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let upstream = branch.upstream, !upstream.isEmpty {
                        Text(upstream)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
        }
        .disabled(!isEnabled)
    }
}
