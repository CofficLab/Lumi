import Foundation
import LumiUI
import ProviderGit
import SwiftUI

/// Commit 列表行：message（1 行截断） + 次行「作者 · 相对时间 · hash前7」。
///
/// 相对时间用 `RelativeDateTimeFormatter` 本地化；hash 用等宽字体。
struct GitCommitRow: View {
    @LumiTheme private var theme

    let commit: GitCommitLog
    let isSelected: Bool
    var onTap: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(commit.author)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("·").foregroundColor(theme.textTertiary)
                    Text(relativeTime)
                    Text("·").foregroundColor(theme.textTertiary)
                    Text(String(commit.hash.prefix(7)))
                        .font(.system(size: 10, design: .monospaced))
                }
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? theme.primary : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        Group {
            if isSelected {
                theme.appListRowSelectedBackground
            } else {
                Color.clear
            }
        }
    }

    private var relativeTime: String {
        guard let date = GitDateFormatting.date(from: commit.date) else {
            return commit.date
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
