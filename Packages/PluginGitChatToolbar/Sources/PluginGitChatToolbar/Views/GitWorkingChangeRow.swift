import LumiUI
import ProviderGit
import SwiftUI

/// 工作区变更文件行：状态徽标 + 等宽路径 + staged 指示。
///
/// 视觉对齐 PluginGitWorkspace 的 GitWorkspaceView（等宽字体 + 状态字母徽标）。
struct GitWorkingChangeRow: View {
    @LumiTheme private var theme

    let change: GitWorkingChange
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

                if change.isStaged {
                    Text("S")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(theme.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 2))
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
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
