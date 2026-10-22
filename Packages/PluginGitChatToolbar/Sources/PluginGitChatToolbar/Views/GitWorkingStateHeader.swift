import LumiUI
import SwiftUI

/// 工作区状态摘要行：分支徽标 + 仓库路径。
///
/// 位于 Changes 段列表顶部，说明当前变更属于哪个仓库的哪个分支。
struct GitWorkingStateHeader: View {
    @LumiTheme private var theme

    let branch: String
    let repositoryPath: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.primary)

            Text(branch)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            if let repositoryPath {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)

                // 仓库路径过长时横向滚动查看完整路径。
                GitPathText(
                    path: repositoryPath,
                    font: .system(size: 10),
                    color: theme.textSecondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
