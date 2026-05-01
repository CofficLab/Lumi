import Foundation
@preconcurrency import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages

@MainActor
final class MarkdownHighlightContributor: SuperEditorHighlightProviderContributor {
    let id = "builtin.markdown.highlight-provider"
    private let supportedLanguageIDs: Set<String> = ["markdown", "markdown-inline", "md", "mdx"]
    private let provider = MarkdownHighlightProvider()

    func supports(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId.lowercased())
    }

    func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        [provider]
    }
}

enum MarkdownHighlightScanner {
    private static let linePatterns: [(NSRegularExpression, CaptureName)] = [
        (try! NSRegularExpression(pattern: #"(?m)^#{1,6}\s+.*$"#), .keyword),
        (try! NSRegularExpression(pattern: #"(?m)^\s{0,3}>\s?.*$"#), .comment),
        (try! NSRegularExpression(pattern: #"(?m)^\s{0,3}(?:[-+*]|\d+\.)\s+"#), .keyword),
        (try! NSRegularExpression(pattern: #"(?m)^\s{0,3}```.*$"#), .string)
    ]

    private static let inlinePatterns: [(NSRegularExpression, CaptureName)] = [
        (try! NSRegularExpression(pattern: #"`[^`\n]+`"#), .string),
        (try! NSRegularExpression(pattern: #"\[[^\]]+\]\([^)]+\)"#), .function),
        (try! NSRegularExpression(pattern: #"\*\*[^*\n]+\*\*|__[^_\n]+__"#), .type),
        (try! NSRegularExpression(pattern: #"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#), .typeAlternate)
    ]

    static func highlights(in text: String, visibleRange: NSRange) -> [HighlightRange] {
        let nsText = text as NSString
        let boundedRange = NSIntersectionRange(visibleRange, NSRange(location: 0, length: nsText.length))
        guard boundedRange.length > 0 else { return [] }

        let scanRange = nsText.lineRange(for: boundedRange)
        var highlights: [HighlightRange] = []

        for (regex, capture) in linePatterns {
            appendMatches(
                for: regex,
                capture: capture,
                in: nsText,
                scanRange: scanRange,
                visibleRange: boundedRange,
                into: &highlights
            )
        }

        for (regex, capture) in inlinePatterns {
            appendMatches(
                for: regex,
                capture: capture,
                in: nsText,
                scanRange: scanRange,
                visibleRange: boundedRange,
                into: &highlights
            )
        }

        return highlights
    }

    private static func appendMatches(
        for regex: NSRegularExpression,
        capture: CaptureName,
        in text: NSString,
        scanRange: NSRange,
        visibleRange: NSRange,
        into highlights: inout [HighlightRange]
    ) {
        regex.enumerateMatches(in: text as String, options: [], range: scanRange) { match, _, _ in
            guard let match else { return }
            let intersection = NSIntersectionRange(match.range, visibleRange)
            guard intersection.length > 0 else { return }
            highlights.append(HighlightRange(range: intersection, capture: capture))
        }
    }
}

@MainActor
final class MarkdownHighlightProvider: HighlightProviding {
    func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        // No-op
    }

    func applyEdit(
        textView: TextView,
        range: NSRange,
        delta: Int,
        completion: @escaping @MainActor (Result<IndexSet, Error>) -> Void
    ) {
        let documentLength = textView.string.utf16.count
        let clampedStart = min(max(0, range.location), documentLength)
        let clampedEnd = min(max(clampedStart, range.location + range.length + max(delta, 0)), documentLength)
        let invalidated = (textView.string as NSString).lineRange(for: NSRange(location: clampedStart, length: max(0, clampedEnd - clampedStart)))
        completion(.success(IndexSet(integersIn: invalidated.location..<(invalidated.location + invalidated.length))))
    }

    func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        completion(.success(MarkdownHighlightScanner.highlights(in: textView.string, visibleRange: range)))
    }
}
