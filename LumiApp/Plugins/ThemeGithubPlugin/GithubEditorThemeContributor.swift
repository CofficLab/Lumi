import Foundation
import CodeEditSourceEditor
import AppKit

/// GitHub 编辑器主题配色方案
/// 参照 VS Code GitHub Dark Default 主题配色
@MainActor
final class GithubEditorThemeContributor: EditorThemeContributor {
    let id: String = "github"
    let displayName: String = "GitHub Dark"
    let icon: String? = "chevron.left.forwardslash.chevron.right"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            // 文字颜色: #c9d1d9 -> (0.788, 0.820, 0.851)
            text: attr(0.788, 0.820, 0.851),
            // 插入点光标: #58a6ff -> (0.345, 0.651, 1.0)
            insertionPoint: color(0.345, 0.651, 1.0),
            // 不可见字符: #484f58 -> (0.282, 0.310, 0.345)
            invisibles: attr(0.282, 0.310, 0.345),
            // 背景: #0d1117 -> (0.051, 0.067, 0.090)
            background: color(0.051, 0.067, 0.090),
            // 行高亮: #161b22 -> (0.086, 0.106, 0.133)
            lineHighlight: color(0.086, 0.106, 0.133),
            // 选择: #388bfd4d -> (0.220, 0.549, 0.996, 0.3)
            selection: color(0.220, 0.549, 0.996, 0.3),
            // 关键字: #ff7b72 -> (1.0, 0.482, 0.447)
            keywords: attr(1.0, 0.482, 0.447),
            // 命令: #c9d1d9 -> (0.788, 0.820, 0.851)
            commands: attr(0.788, 0.820, 0.851),
            // 类型: #7ee787 -> (0.494, 0.906, 0.529)
            types: attr(0.494, 0.906, 0.529),
            // 属性: #d2a8ff -> (0.824, 0.659, 1.0)
            attributes: attr(0.824, 0.659, 1.0),
            // 变量: #ffa657 -> (1.0, 0.651, 0.341)
            variables: attr(1.0, 0.651, 0.341),
            // 值: #c9d1d9 -> (0.788, 0.820, 0.851)
            values: attr(0.788, 0.820, 0.851),
            // 数字: #79c0ff -> (0.475, 0.753, 1.0)
            numbers: attr(0.475, 0.753, 1.0),
            // 字符串: #a5d6ff -> (0.647, 0.839, 1.0)
            strings: attr(0.647, 0.839, 1.0),
            // 字符: #a5d6ff -> (0.647, 0.839, 1.0)
            characters: attr(0.647, 0.839, 1.0),
            // 注释: #8b949e -> (0.545, 0.580, 0.620)
            comments: attr(0.545, 0.580, 0.620)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
