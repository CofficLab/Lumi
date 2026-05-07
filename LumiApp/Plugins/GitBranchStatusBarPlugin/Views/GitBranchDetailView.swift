import SwiftUI
import MagicKit

/// Git 分支详情视图（在 popover 中显示）
struct GitBranchDetailView: View {
    let branchName: String?
    let isDirty: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text(String(localized: "Git Information", table: "GitBranchStatusBar"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            if let branch = branchName {
                GitInfoRow(label: String(localized: "Current Branch", table: "GitBranchStatusBar"), value: branch)

                if let dirty = isDirty {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(String(localized: "Status", table: "GitBranchStatusBar"))
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(width: 70, alignment: .leading)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(dirty ? DesignTokens.Color.semantic.warning : DesignTokens.Color.semantic.success)
                                .frame(width: 6, height: 6)

                            Text(dirty
                                ? String(localized: "Uncommitted Changes", table: "GitBranchStatusBar")
                                : String(localized: "Clean Working Tree", table: "GitBranchStatusBar"))
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                        }

                        Spacer()
                    }
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(DesignTokens.Color.semantic.warning)

                    Text(String(localized: "Unable to Get Git Information", table: "GitBranchStatusBar"))
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
    }
}

/// Git 信息行
struct GitInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - 预览

#Preview("Detail View") {
    GitBranchDetailView(branchName: "main", isDirty: true)
        .frame(width: 300)
}
