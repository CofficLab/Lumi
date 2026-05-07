import Foundation
import AppKit
import EditorKernelCore

/// XCConfig 语法高亮和编辑支持
enum XCConfigSyntax {
    typealias IncludeDirective = XCConfigSyntaxCore.IncludeDirective
    typealias KeyOccurrence = XCConfigSyntaxCore.KeyOccurrence
    typealias Token = XCConfigSyntaxCore.Token
    typealias TokenType = XCConfigSyntaxCore.TokenType

    static func tokenize(_ content: String) -> [Token] {
        XCConfigSyntaxCore.tokenize(content)
    }

    static func includeDirective(at location: Int, in content: String) -> IncludeDirective? {
        XCConfigSyntaxCore.includeDirective(at: location, in: content)
    }

    static func resolveIncludedFileURL(
        for directive: IncludeDirective,
        currentFileURL: URL
    ) -> URL? {
        XCConfigSyntaxCore.resolveIncludedFileURL(for: directive, currentFileURL: currentFileURL)
    }

    static func keyOccurrences(in content: String) -> [KeyOccurrence] {
        XCConfigSyntaxCore.keyOccurrences(in: content)
    }
    
    /// 应用语法高亮到 text storage
    static func applyHighlighting(to textStorage: NSTextStorage, range: NSRange) {
        let content = textStorage.string
        let tokens = tokenize(content)
        
        for token in tokens where NSIntersectionRange(token.range, range).length > 0 {
            let color: NSColor
            let fontAttribute: [NSAttributedString.Key: Any]
            
            switch token.type {
            case .comment:
                color = NSColor.systemGray
                fontAttribute = [.foregroundColor: color]
            case .include:
                color = NSColor.systemPurple
                fontAttribute = [.foregroundColor: color]
            case .key:
                color = NSColor.systemBlue
                fontAttribute = [.foregroundColor: color, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)]
            case .value:
                color = NSColor.systemOrange
                fontAttribute = [.foregroundColor: color]
            case .operatorSymbol:
                color = NSColor.systemRed
                fontAttribute = [.foregroundColor: color]
            case .preprocessor:
                color = NSColor.systemCyan
                fontAttribute = [.foregroundColor: color]
            case .string:
                color = NSColor.systemGreen
                fontAttribute = [.foregroundColor: color]
            }
            
            textStorage.addAttributes(fontAttribute, range: token.range)
        }
    }
}

