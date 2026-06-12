import CodeEditSourceEditor
import Foundation
import LumiUI

@MainActor
public enum EditorBuiltinSyntaxThemes {
  public static func registerFallbacks(into registry: EditorExtensionRegistry) {
    registerPaletteContributor(
      id: "xcode-dark",
      displayName: "Xcode Dark",
      isDark: true,
      palette: .preset(.xcodeDark),
      into: registry
    )
    registerPaletteContributor(
      id: "xcode-light",
      displayName: "Xcode Light",
      isDark: false,
      palette: .preset(.xcodeLight),
      into: registry
    )
  }

  /// 从 LumiUI 主题贡献展开并注册语法调色板。
  public static func registerAppThemes(
    _ contributions: [LumiUIThemeContribution],
    into registry: EditorExtensionRegistry
  ) {
    for contribution in contributions {
      let chrome = contribution.chromeTheme
      for scheme in EditorSyntaxPaletteSchemes.colorSchemes(for: chrome.appearanceKind) {
        let themeId = chrome.resolvedEditorThemeId(
          defaultEditorThemeId: contribution.editorThemeId,
          colorScheme: scheme
        )
        let palette = chrome.editorSyntaxPalette(colorScheme: scheme)
        registerPaletteContributor(
          id: themeId,
          displayName: contribution.displayName,
          isDark: scheme == .dark,
          palette: palette,
          into: registry
        )
      }
    }

    for contribution in contributions {
      if let contributor = contribution.attachments.editorThemeContributor as? any SuperEditorThemeContributor {
        registry.registerOrReplaceThemeContributor(contributor)
      }
    }
  }

  private static func registerPaletteContributor(
    id: String,
    displayName: String,
    isDark: Bool,
    palette: EditorSyntaxPalette,
    into registry: EditorExtensionRegistry
  ) {
    registry.registerOrReplaceThemeContributor(
      PaletteSyntaxThemeContributor(
        id: id,
        displayName: displayName,
        isDark: isDark,
        palette: palette
      )
    )
  }
}
