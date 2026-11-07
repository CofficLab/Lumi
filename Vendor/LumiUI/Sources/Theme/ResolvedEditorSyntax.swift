import SwiftUI

/// 解析后的编辑器语法主题（ID + 调色板）。
public struct ResolvedEditorSyntax: Sendable, Equatable {
    public let themeId: String
    public let palette: EditorSyntaxPalette
    public let isDark: Bool

    public init(themeId: String, palette: EditorSyntaxPalette, isDark: Bool) {
        self.themeId = themeId
        self.palette = palette
        self.isDark = isDark
    }
}
