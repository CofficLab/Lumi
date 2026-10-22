import LumiUI
import ProviderGit
import SwiftUI

/// 工作区变更文件行：状态徽标 + 可横向滚动的等宽路径 + staged 指示。
///
/// 视觉对齐 PluginGitWorkspace 的 GitWorkspaceView（等宽字体 + 状态字母徽标）。
struct GitWorkingChangeRow: View {
    @LumiTheme private var theme

    let change: GitWorkingChange
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(labelColor)
                .frame(width: 16, alignment: .center)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(labelColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))

            if change.isStaged {
                Text("S")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(theme.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 2))
            }

            // 路径占据剩余宽度，内容超出时横向滚动查看完整路径。
            GitPathText(path: change.path, color: theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        // 不用 Button 包裹：Button 会吞掉路径区域的拖动手势，导致无法横向滚动。
        // 用 simultaneousGesture 让点击与横向拖动并存。
        .simultaneousGesture(
            TapGesture().onEnded { onTap?() }
        )
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
