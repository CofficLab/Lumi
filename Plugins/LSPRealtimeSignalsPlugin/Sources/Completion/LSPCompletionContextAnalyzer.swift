import Foundation

/// Parsed editor context for a completion request.
public struct LSPCompletionContext: Equatable, Sendable {
    public let prefix: String
    public let isTypeContext: Bool
    /// `true` when the cursor is immediately after `.` (enum member / member access).
    public let isMemberAccessContext: Bool

    public init(prefix: String, isTypeContext: Bool, isMemberAccessContext: Bool) {
        self.prefix = prefix
        self.isTypeContext = isTypeContext
        self.isMemberAccessContext = isMemberAccessContext
    }
}

public enum LSPCompletionContextAnalyzer {
    public static func analyze(atOffset rawOffset: Int, in content: String) -> LSPCompletionContext {
        let cursorOffset = min(max(rawOffset, 0), content.utf16.count)
        let ns = content as NSString
        var tokenStart = cursorOffset
        while tokenStart > 0 {
            let unit = ns.character(at: tokenStart - 1)
            guard isIdentifierScalar(unit) else { break }
            tokenStart -= 1
        }
        let prefix = ns.substring(with: NSRange(location: tokenStart, length: cursorOffset - tokenStart))
        var check = tokenStart
        while check > 0 {
            let unit = ns.character(at: check - 1)
            if let scalar = UnicodeScalar(unit),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                check -= 1
                continue
            }
            return LSPCompletionContext(
                prefix: prefix,
                isTypeContext: unit == 0x3A, // ":"
                isMemberAccessContext: unit == 0x2E // "."
            )
        }
        return LSPCompletionContext(prefix: prefix, isTypeContext: false, isMemberAccessContext: false)
    }

    private static func isIdentifierScalar(_ scalar: unichar) -> Bool {
        if scalar == 0x5F { return true } // "_"
        guard let unit = UnicodeScalar(scalar) else { return false }
        return CharacterSet.alphanumerics.contains(unit)
    }
}
