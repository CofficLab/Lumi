import EditorSource
import Foundation
import LumiUI

@MainActor
public final class PaletteSyntaxThemeContributor: SuperEditorThemeContributor {
  public let id: String
  public let displayName: String
  public let icon: String?
  public let isDark: Bool
  private let palette: EditorSyntaxPalette

  public init(
    id: String,
    displayName: String,
    isDark: Bool,
    palette: EditorSyntaxPalette,
    icon: String? = "paintpalette"
  ) {
    self.id = id
    self.displayName = displayName
    self.isDark = isDark
    self.palette = palette
    self.icon = icon
  }

  public func createTheme() -> EditorTheme {
    EditorSyntaxPaletteAdapter.makeEditorTheme(from: palette)
  }
}
