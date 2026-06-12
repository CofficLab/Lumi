import Foundation

public struct StringCatalogPlaceholder: Equatable, Sendable {
    public let range: Range<String.Index>
    public let value: Substring
}

public enum StringCatalogPlaceholderScanner {
    public static func placeholders(in text: String) -> [StringCatalogPlaceholder] {
        guard !text.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return StringCatalogPlaceholder(range: range, value: text[range])
        }
    }

    private static let pattern = #"%(?:\d+\$)?(?:[-+#0 ]*\d*(?:\.\d+)?)?(?:hh|h|ll|l|L|z|t|j)?[@aAcCdiouxXeEfFgGsSp]"#
}
