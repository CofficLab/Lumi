import SwiftUI
import MagicKit

/// 项目文件树头部视图
struct ProjectTreeHeader: View {
    let projectRoot: URL?
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text("项目文件")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                // 刷新按钮
                refreshButton
            }

            // 项目路径
            if let projectRoot = projectRoot {
                pathLabel(projectRoot)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func pathLabel(_ url: URL) -> some View {
        Text(url.path)
            .font(.system(size: 9))
            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            .lineLimit(2)
            .truncationMode(.middle)
    }
}
