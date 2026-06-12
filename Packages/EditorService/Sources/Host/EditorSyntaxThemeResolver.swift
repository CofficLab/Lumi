import CodeEditSourceEditor
import LumiUI
import SwiftUI

/// 编辑器语法主题唯一解析入口。
@MainActor
public enum EditorSyntaxThemeResolver {
  public struct ResolvedTheme {
    public let id: String
    public let theme: EditorTheme

    public init(id: String, theme: EditorTheme) {
      self.id = id
      self.theme = theme
    }
  }

  public static func resolve(
    registry: LumiUIThemeRegistry,
    extensions: EditorExtensionRegistry,
    colorScheme: ColorScheme
  ) -> ResolvedTheme {
    if let resolved = registry.resolvedEditorSyntax(colorScheme: colorScheme) {
      if let contributor = extensions.theme(for: resolved.themeId) {
        return ResolvedTheme(id: resolved.themeId, theme: contributor.createTheme())
      }
      return ResolvedTheme(
        id: resolved.themeId,
        theme: EditorSyntaxPaletteAdapter.makeEditorTheme(from: resolved.palette)
      )
    }

    let fallbackID = colorScheme == .dark ? "xcode-dark" : "xcode-light"
    if let contributor = extensions.theme(for: fallbackID) {
      return ResolvedTheme(id: fallbackID, theme: contributor.createTheme())
    }

    let palette = EditorSyntaxPalette.standard(isDark: colorScheme == .dark)
    return ResolvedTheme(
      id: fallbackID,
      theme: EditorSyntaxPaletteAdapter.makeEditorTheme(from: palette)
    )
  }
}
