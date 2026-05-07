import Foundation
import CodeEditSourceEditor
import AppKit

/// VS Code Light+ 编辑器主题配色方案
/// 严格遵循 Visual Studio Code Light Modern (Light+) 默认主题
/// 参考: https://github.com/microsoft/vscode/tree/main/extensions/theme-defaults/themes
@MainActor
final class VscodeLightSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "vscode-light"
    let displayName: String = "VS Code Light+"
    let icon: String? = "terminal"
    let isDark: Bool = false

    func createTheme() -> EditorTheme {
        EditorTheme(
            // 文字颜色: #333333 -> (0.200, 0.200, 0.200)
            text: attr(0.200, 0.200, 0.200),
            // 插入点光标: #000000 -> (0.0, 0.0, 0.0)
            insertionPoint: color(0.0, 0.0, 0.0),
            // 不可见字符: #E5E5E5 -> (0.898, 0.898, 0.898)
            invisibles: attr(0.898, 0.898, 0.898),
            // 背景: #FFFFFF -> (1.0, 1.0, 1.0)
            background: color(1.0, 1.0, 1.0),
            // 行高亮: #E8E8E8 -> (0.910, 0.910, 0.910)
            lineHighlight: color(0.910, 0.910, 0.910),
            // 选择: #ADD6FF -> (0.678, 0.847, 1.0, 0.5)
            selection: color(0.678, 0.847, 1.0, 0.5),
            // 关键字: #0000FF -> (0.0, 0.0, 1.0)
            keywords: attr(0.0, 0.0, 1.0),
            // 命令: #333333 -> (0.200, 0.200, 0.200)
            commands: attr(0.200, 0.200, 0.200),
            // 类型/类: #267F99 -> (0.149, 0.498, 0.600)
            types: attr(0.149, 0.498, 0.600),
            // 属性/装饰器: #795E26 -> (0.475, 0.369, 0.149)
            attributes: attr(0.475, 0.369, 0.149),
            // 变量/参数: #001080 -> (0.0, 0.063, 0.502)
            variables: attr(0.0, 0.063, 0.502),
            // 值: #333333 -> (0.200, 0.200, 0.200)
            values: attr(0.200, 0.200, 0.200),
            // 数字: #098658 -> (0.035, 0.525, 0.345)
            numbers: attr(0.035, 0.525, 0.345),
            // 字符串: #A31515 -> (0.639, 0.082, 0.082)
            strings: attr(0.639, 0.082, 0.082),
            // 字符: #A31515 -> (0.639, 0.082, 0.082)
            characters: attr(0.639, 0.082, 0.082),
            // 注释: #008000 -> (0.0, 0.502, 0.0)
            comments: attr(0.0, 0.502, 0.0)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
