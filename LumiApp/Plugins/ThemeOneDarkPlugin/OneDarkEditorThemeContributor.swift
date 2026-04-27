import Foundation
import CodeEditSourceEditor
import AppKit

/// One Dark Pro 编辑器主题配色方案
/// 严格遵循 Atom One Dark (One Dark Pro) 默认主题
/// 参考: https://github.com/atom/atom-dark-syntax
@MainActor
final class OneDarkEditorThemeContributor: EditorThemeContributor {
    let id: String = "one-dark"
    let displayName: String = "One Dark"
    let icon: String? = "circle.hexagongrid"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            // 文字颜色: #ABB2BF -> (0.671, 0.698, 0.749)
            text: attr(0.671, 0.698, 0.749),
            // 插入点光标: #528BFF -> (0.322, 0.545, 1.0)
            insertionPoint: color(0.322, 0.545, 1.0),
            // 不可见字符: #5C6370 -> (0.361, 0.388, 0.439)
            invisibles: attr(0.361, 0.388, 0.439),
            // 背景: #282C34 -> (0.157, 0.173, 0.204)
            background: color(0.157, 0.173, 0.204),
            // 行高亮: #2C313A -> (0.173, 0.192, 0.227)
            lineHighlight: color(0.173, 0.192, 0.227),
            // 选择: #3E4451 -> (0.243, 0.267, 0.318, 0.5)
            selection: color(0.243, 0.267, 0.318, 0.5),
            // 关键字: #C678DD -> (0.776, 0.471, 0.867)
            keywords: attr(0.776, 0.471, 0.867),
            // 命令: #ABB2BF -> (0.671, 0.698, 0.749)
            commands: attr(0.671, 0.698, 0.749),
            // 类型/类: #E5C07B -> (0.898, 0.753, 0.482)
            types: attr(0.898, 0.753, 0.482),
            // 属性/装饰器: #D19A66 -> (0.820, 0.604, 0.400)
            attributes: attr(0.820, 0.604, 0.400),
            // 变量/参数: #E06C75 -> (0.878, 0.424, 0.459)
            variables: attr(0.878, 0.424, 0.459),
            // 值: #56B6C2 -> (0.337, 0.714, 0.761)
            values: attr(0.337, 0.714, 0.761),
            // 数字: #D19A66 -> (0.820, 0.604, 0.400)
            numbers: attr(0.820, 0.604, 0.400),
            // 字符串: #98C379 -> (0.596, 0.765, 0.475)
            strings: attr(0.596, 0.765, 0.475),
            // 字符: #98C379 -> (0.596, 0.765, 0.475)
            characters: attr(0.596, 0.765, 0.475),
            // 注释: #5C6370 -> (0.361, 0.388, 0.439)
            comments: attr(0.361, 0.388, 0.439)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
