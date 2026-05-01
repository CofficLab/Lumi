import Foundation
import CodeEditSourceEditor
import AppKit

/// Dracula Official 编辑器主题配色方案
/// 严格遵循 Dracula Theme 官方配色标准
/// 参考: https://draculatheme.com/contribute
@MainActor
final class DraculaSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "dracula"
    let displayName: String = "Dracula"
    let icon: String? = "moon.stars.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            // 当前行: #343746 -> (0.204, 0.216, 0.275)
            text: attr(0.671, 0.698, 0.749),
            // 插入点光标: #F8F8F0 -> (0.973, 0.973, 0.941)
            insertionPoint: color(0.973, 0.973, 0.941),
            // 不可见字符: #44475A -> (0.267, 0.278, 0.353)
            invisibles: attr(0.267, 0.278, 0.353),
            // 背景: #282A36 -> (0.157, 0.165, 0.212)
            background: color(0.157, 0.165, 0.212),
            // 行高亮: #343746 -> (0.204, 0.216, 0.275)
            lineHighlight: color(0.204, 0.216, 0.275),
            // 选择: #44475A -> (0.267, 0.278, 0.353, 0.5)
            selection: color(0.267, 0.278, 0.353, 0.5),
            // 关键字: #FF79C6 -> (1.0, 0.475, 0.776)
            keywords: attr(1.0, 0.475, 0.776),
            // 命令: #F8F8F2 -> (0.973, 0.973, 0.949)
            commands: attr(0.973, 0.973, 0.949),
            // 类型/类: #50FA7B -> (0.314, 0.980, 0.482)
            types: attr(0.314, 0.980, 0.482),
            // 属性/装饰器: #FFB86C -> (1.0, 0.722, 0.424)
            attributes: attr(1.0, 0.722, 0.424),
            // 变量/参数: #F8F8F2 -> (0.973, 0.973, 0.949)
            variables: attr(0.973, 0.973, 0.949),
            // 值: #BD93F9 -> (0.741, 0.576, 0.976)
            values: attr(0.741, 0.576, 0.976),
            // 数字: #BD93F9 -> (0.741, 0.576, 0.976)
            numbers: attr(0.741, 0.576, 0.976),
            // 字符串: #F1FA8C -> (0.945, 0.980, 0.549)
            strings: attr(0.945, 0.980, 0.549),
            // 字符: #F1FA8C -> (0.945, 0.980, 0.549)
            characters: attr(0.945, 0.980, 0.549),
            // 注释: #6272A4 -> (0.384, 0.447, 0.643)
            comments: attr(0.384, 0.447, 0.643)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
