import AppKit
import EditorSource
import LumiUI

/// 将 LumiUI `EditorSyntaxPalette` 转为 CodeEdit `EditorTheme`。
public enum EditorSyntaxPaletteAdapter {
  @MainActor
  public static func makeEditorTheme(from palette: EditorSyntaxPalette) -> EditorTheme {
    EditorTheme(
      text: makeAttribute(palette.text),
      insertionPoint: makeColor(palette.insertionPointHex),
      invisibles: makeAttribute(palette.invisibles),
      background: makeColor(palette.backgroundHex),
      lineHighlight: makeColor(palette.lineHighlightHex),
      selection: makeColor(palette.selectionHex, alpha: palette.selectionAlpha),
      keywords: makeAttribute(palette.keywords),
      commands: makeAttribute(palette.commands),
      types: makeAttribute(palette.types),
      attributes: makeAttribute(palette.attributes),
      variables: makeAttribute(palette.variables),
      values: makeAttribute(palette.values),
      numbers: makeAttribute(palette.numbers),
      strings: makeAttribute(palette.strings),
      characters: makeAttribute(palette.characters),
      comments: makeAttribute(palette.comments)
    )
  }

  private static func makeAttribute(_ style: EditorSyntaxTextStyle) -> EditorTheme.Attribute {
    EditorTheme.Attribute(
      color: makeColor(style.colorHex),
      bold: style.bold,
      italic: style.italic
    )
  }

  private static func makeColor(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
    let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: trimmed).scanHexInt64(&int)

    let r, g, b: CGFloat
    switch trimmed.count {
    case 6:
      r = CGFloat((int >> 16) & 0xFF) / 255
      g = CGFloat((int >> 8) & 0xFF) / 255
      b = CGFloat(int & 0xFF) / 255
    case 8:
      let alphaComponent = CGFloat((int >> 24) & 0xFF) / 255
      r = CGFloat((int >> 16) & 0xFF) / 255
      g = CGFloat((int >> 8) & 0xFF) / 255
      b = CGFloat(int & 0xFF) / 255
      return NSColor(red: r, green: g, blue: b, alpha: alphaComponent)
    default:
      return NSColor.white.withAlphaComponent(alpha)
    }

    return NSColor(red: r, green: g, blue: b, alpha: alpha)
  }
}
