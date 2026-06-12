import Foundation
import EditorService
@preconcurrency import EditorSource
import EditorTextView
import EditorLanguages

@MainActor
public final class MarkdownHighlightContributor: SuperEditorHighlightProviderContributor {
    public let id = "builtin.markdown.highlight-provider"
    private let supportedLanguageIDs: Set<String> = ["markdown", "markdown-inline", "md", "mdx"]
    private let provider = MarkdownHighlightProvider()

    public func supports(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId.lowercased())
    }

    public func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        [provider]
    }
}

public enum MarkdownHighlightScanner {
    private static let linePatterns: [(NSRegularExpression, CaptureName)] = [
        (makeRegex(#"(?m)^#{1,6}\s+.*$"#), .keyword),
        (makeRegex(#"(?m)^\s{0,3}>\s?.*$"#), .comment),
        (makeRegex(#"(?m)^\s{0,3}(?:[-+*]|\d+\.)\s+"#), .keyword)
    ]

    private static let inlinePatterns: [(NSRegularExpression, CaptureName)] = [
        (makeRegex(#"`[^`\n]+`"#), .string),
        (makeRegex(#"\[[^\]]+\]\([^)]+\)"#), .function),
        (makeRegex(#"\*\*[^*\n]+\*\*|__[^_\n]+__"#), .type),
        (makeRegex(#"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#), .typeAlternate)
    ]

    public static func highlights(in text: String, visibleRange: NSRange) -> [HighlightRange] {
        let nsText = text as NSString
        let boundedRange = NSIntersectionRange(visibleRange, NSRange(location: 0, length: nsText.length))
        guard boundedRange.length > 0 else { return [] }

        let scanRange = nsText.lineRange(for: boundedRange)
        var highlights: [HighlightRange] = []
        let fencedCodeRanges = fencedCodeBlockRanges(in: nsText)

        for range in fencedCodeRanges {
            let intersection = NSIntersectionRange(range, boundedRange)
            guard intersection.length > 0 else { continue }
            highlights.append(HighlightRange(range: intersection, capture: .string))
        }

        for (regex, capture) in linePatterns {
            appendMatches(
                for: regex,
                capture: capture,
                in: nsText,
                scanRange: scanRange,
                visibleRange: boundedRange,
                excludedRanges: fencedCodeRanges,
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
                excludedRanges: fencedCodeRanges,
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
        excludedRanges: [NSRange],
        into highlights: inout [HighlightRange]
    ) {
        regex.enumerateMatches(in: text as String, options: [], range: scanRange) { match, _, _ in
            guard let match else { return }
            guard !excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else {
                return
            }
            let intersection = NSIntersectionRange(match.range, visibleRange)
            guard intersection.length > 0 else { return }
            highlights.append(HighlightRange(range: intersection, capture: capture))
        }
    }

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid Markdown regex: \(pattern)")
        }
    }

    private static func fencedCodeBlockRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = 0
        var openFence: (start: Int, marker: Character, count: Int)?

        while location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            let line = text.substring(with: lineRange)

            if let fence = openFence {
                if isClosingFence(line, marker: fence.marker, count: fence.count) {
                    ranges.append(NSRange(location: fence.start, length: NSMaxRange(lineRange) - fence.start))
                    openFence = nil
                }
            } else if let fence = openingFence(in: line) {
                openFence = (start: lineRange.location, marker: fence.marker, count: fence.count)
            }

            let next = NSMaxRange(lineRange)
            guard next > location else { break }
            location = next
        }

        if let fence = openFence {
            ranges.append(NSRange(location: fence.start, length: text.length - fence.start))
        }

        return ranges
    }

    private static func openingFence(in line: String) -> (marker: Character, count: Int)? {
        let trimmed = line.dropFirst(min(leadingSpaceCount(in: line), 3))
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        return (first, count)
    }

    private static func isClosingFence(_ line: String, marker: Character, count: Int) -> Bool {
        let trimmed = line.dropFirst(min(leadingSpaceCount(in: line), 3))
        guard trimmed.prefix(count).allSatisfy({ $0 == marker }) else { return false }
        let markerCount = trimmed.prefix(while: { $0 == marker }).count
        guard markerCount >= count else { return false }
        return trimmed.dropFirst(markerCount).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func leadingSpaceCount(in line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }
}

@MainActor
public final class MarkdownHighlightProvider: HighlightProviding {
    public func setUp(textView: TextView, codeLanguage: CodeLanguage) {
        // No-op
    }

    public func applyEdit(
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

    public func queryHighlightsFor(
        textView: TextView,
        range: NSRange,
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        completion(.success(MarkdownHighlightScanner.highlights(in: textView.string, visibleRange: range)))
    }
}
