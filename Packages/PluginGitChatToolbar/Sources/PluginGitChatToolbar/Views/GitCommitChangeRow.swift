import LumiUI
import ProviderGit
import SwiftUI

/// Commit 变更文件行：状态徽标 + 等宽路径。
///
/// 与 ``GitWorkingChangeRow`` 视觉一致，但不显示 staged 标记
/// （commit 内的文件没有「已暂存」概念）。
struct GitCommitChangeRow: View {
    @LumiTheme private var theme

    let change: GitCommitChange
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(labelColor)
                    .frame(width: 16, alignment: .center)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(labelColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))

                Text(change.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var label: String {
        switch change.state {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .untracked: return "?"
        }
    }

    private var labelColor: Color {
        switch change.state {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .gray
        }
    }
}
