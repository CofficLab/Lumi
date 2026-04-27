import Foundation
import CodeEditSourceEditor
import AppKit

/// VS Code Dark+ 编辑器主题配色方案
/// 严格遵循 Visual Studio Code Dark Modern (Dark+) 默认主题
/// 参考: https://github.com/microsoft/vscode/tree/main/extensions/theme-defaults/themes
@MainActor
final class VscodeDarkEditorThemeContributor: EditorThemeContributor {
    let id: String = "vscode-dark"
    let displayName: String = "VS Code Dark+"
    let icon: String? = "terminal.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            // 文字颜色: #D4D4D4 -> (0.831, 0.831, 0.831)
            text: attr(0.831, 0.831, 0.831),
            // 插入点光标: #AEAFAD -> (0.682, 0.686, 0.678)
            insertionPoint: color(0.682, 0.686, 0.678),
            // 不可见字符: #3B3B3B -> (0.231, 0.231, 0.231)
            invisibles: attr(0.231, 0.231, 0.231),
            // 背景: #1E1E1E -> (0.118, 0.118, 0.118)
            background: color(0.118, 0.118, 0.118),
            // 行高亮: #2A2D2E -> (0.165, 0.176, 0.180)
            lineHighlight: color(0.165, 0.176, 0.180),
            // 选择: #264F78 -> (0.149, 0.310, 0.471, 0.5)
            selection: color(0.149, 0.310, 0.471, 0.5),
            // 关键字: #569CD6 -> (0.337, 0.612, 0.839)
            keywords: attr(0.337, 0.612, 0.839),
            // 命令: #D4D4D4 -> (0.831, 0.831, 0.831)
            commands: attr(0.831, 0.831, 0.831),
            // 类型/类: #4EC9B0 -> (0.306, 0.788, 0.690)
            types: attr(0.306, 0.788, 0.690),
            // 属性/装饰器: #DCDCAA -> (0.863, 0.863, 0.667)
            attributes: attr(0.863, 0.863, 0.667),
            // 变量/参数: #9CDCFE -> (0.612, 0.863, 0.996)
            variables: attr(0.612, 0.863, 0.996),
            // 值: #D4D4D4 -> (0.831, 0.831, 0.831)
            values: attr(0.831, 0.831, 0.831),
            // 数字: #B5CEA8 -> (0.710, 0.808, 0.659)
            numbers: attr(0.710, 0.808, 0.659),
            // 字符串: #CE9178 -> (0.808, 0.569, 0.471)
            strings: attr(0.808, 0.569, 0.471),
            // 字符: #CE9178 -> (0.808, 0.569, 0.471)
            characters: attr(0.808, 0.569, 0.471),
            // 注释: #6A9955 -> (0.416, 0.600, 0.333)
            comments: attr(0.416, 0.600, 0.333)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
