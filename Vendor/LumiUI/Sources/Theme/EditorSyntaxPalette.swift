import SwiftUI

/// 语法高亮文本样式（不含 NSColor，供 LumiUI 与主题插件使用）。
public struct EditorSyntaxTextStyle: Sendable, Equatable, Hashable {
    public let colorHex: String
    public let bold: Bool
    public let italic: Bool

    public init(colorHex: String, bold: Bool = false, italic: Bool = false) {
        self.colorHex = colorHex
        self.bold = bold
        self.italic = italic
    }

    public static func color(_ hex: String) -> EditorSyntaxTextStyle {
        EditorSyntaxTextStyle(colorHex: hex)
    }
}

/// 编辑器语法高亮调色板（与 CodeEdit `EditorTheme` 字段对齐）。
public struct EditorSyntaxPalette: Sendable, Equatable, Hashable {
    public var text: EditorSyntaxTextStyle
    public var insertionPointHex: String
    public var invisibles: EditorSyntaxTextStyle
    public var backgroundHex: String
    public var lineHighlightHex: String
    public var selectionHex: String
    public var selectionAlpha: Double
    public var keywords: EditorSyntaxTextStyle
    public var commands: EditorSyntaxTextStyle
    public var types: EditorSyntaxTextStyle
    public var attributes: EditorSyntaxTextStyle
    public var variables: EditorSyntaxTextStyle
    public var values: EditorSyntaxTextStyle
    public var numbers: EditorSyntaxTextStyle
    public var strings: EditorSyntaxTextStyle
    public var characters: EditorSyntaxTextStyle
    public var comments: EditorSyntaxTextStyle

    public init(
        text: EditorSyntaxTextStyle,
        insertionPointHex: String,
        invisibles: EditorSyntaxTextStyle,
        backgroundHex: String,
        lineHighlightHex: String,
        selectionHex: String,
        selectionAlpha: Double = 0.6,
        keywords: EditorSyntaxTextStyle,
        commands: EditorSyntaxTextStyle,
        types: EditorSyntaxTextStyle,
        attributes: EditorSyntaxTextStyle,
        variables: EditorSyntaxTextStyle,
        values: EditorSyntaxTextStyle,
        numbers: EditorSyntaxTextStyle,
        strings: EditorSyntaxTextStyle,
        characters: EditorSyntaxTextStyle,
        comments: EditorSyntaxTextStyle
    ) {
        self.text = text
        self.insertionPointHex = insertionPointHex
        self.invisibles = invisibles
        self.backgroundHex = backgroundHex
        self.lineHighlightHex = lineHighlightHex
        self.selectionHex = selectionHex
        self.selectionAlpha = selectionAlpha
        self.keywords = keywords
        self.commands = commands
        self.types = types
        self.attributes = attributes
        self.variables = variables
        self.values = values
        self.numbers = numbers
        self.strings = strings
        self.characters = characters
        self.comments = comments
    }
}

/// 有公开配色规范的主题 preset 标识。
public enum EditorSyntaxPalettePreset: String, Sendable, CaseIterable {
    case xcodeDark
    case xcodeLight
    case dracula
    case oneDark
    case vscodeDark
    case vscodeLight
    case github
    case githubDark
    case lumiDark
    case lumiLight
    case skyDark
    case skyLight
}

/// 按主题外观类型展开需注册的配色方案。
public enum EditorSyntaxPaletteSchemes {
    public static func colorSchemes(for appearanceKind: ThemeAppearanceKind) -> [ColorScheme] {
        switch appearanceKind {
        case .system:
            return [.dark, .light]
        case .dark:
            return [.dark]
        case .light:
            return [.light]
        }
    }
}
