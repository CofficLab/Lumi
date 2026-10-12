import Foundation

/// 语法文本样式，不携带 SwiftUI/AppKit 类型。
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

/// 编辑器语法调色板的业务无关数据模型。
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

/// 一个可撤回的编辑器主题贡献。
public struct EditorThemeContribution: Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let icon: String?
    public let isDark: Bool
    public let palette: EditorSyntaxPalette

    public init(
        id: String,
        displayName: String,
        icon: String? = nil,
        isDark: Bool,
        palette: EditorSyntaxPalette
    ) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.isDark = isDark
        self.palette = palette
    }
}

/// 编辑器主题能力。
@MainActor
public protocol EditorThemeProviding: AnyObject {
    var activeThemeID: String? { get }
    func install(_ contribution: EditorThemeContribution)
    func uninstall(themeID: String)
    func select(themeID: String)
}
