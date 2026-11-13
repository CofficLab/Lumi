import Foundation

public enum EditorFindReplaceController {
    public static func matches(
        in text: String,
        state: EditorFindReplaceState,
        selections: [EditorSelection],
        primarySelection: EditorSelection?
    ) -> EditorFindMatchesResult {
        guard !state.findText.isEmpty else {
            return EditorFindMatchesResult(matches: [], selectedMatchIndex: nil, selectedMatchRange: nil)
        }

        guard let regularExpression = regularExpression(for: state) else {
            return EditorFindMatchesResult(matches: [], selectedMatchIndex: nil, selectedMatchRange: nil)
        }

        let searchScopes = searchScopes(
            in: text,
            options: state.options,
            selections: selections,
            primarySelection: primarySelection
        )

        // 用 NSString 取子串：`Range(_:in:)` 每次都要做一次 UTF-16 → String.Index
        // 的换算，代价随文档长度增长，于是「匹配数 × 文档长度」。
        // NSString 的换算只与匹配本身的长度有关。
        let nsText = text as NSString
        let matches: [EditorFindMatch] = searchScopes.flatMap { scope -> [EditorFindMatch] in
            regularExpression.matches(in: text, options: [], range: scope.nsRange).compactMap { match in
                guard match.range.location >= 0,
                      match.range.length >= 0,
                      NSMaxRange(match.range) <= nsText.length else { return nil }
                return EditorFindMatch(
                    range: EditorRange(location: match.range.location, length: match.range.length),
                    matchedText: nsText.substring(with: match.range)
                )
            }
        }

        let selectedMatchIndex = selectedMatchIndex(
            in: matches,
            preferredRange: state.selectedMatchRange,
            primarySelection: primarySelection
        )

        return EditorFindMatchesResult(
            matches: matches,
            selectedMatchIndex: selectedMatchIndex,
            selectedMatchRange: selectedMatchIndex.flatMap { index in
                guard matches.indices.contains(index) else { return nil }
                return matches[index].range
            }
        )
    }

    public static func nextMatchIndex(
        in matches: [EditorFindMatch],
        selectedMatchIndex: Int?
    ) -> Int? {
        guard !matches.isEmpty else { return nil }
        guard let selectedMatchIndex, matches.indices.contains(selectedMatchIndex) else { return 0 }
        return (selectedMatchIndex + 1) % matches.count
    }

    public static func previousMatchIndex(
        in matches: [EditorFindMatch],
        selectedMatchIndex: Int?
    ) -> Int? {
        guard !matches.isEmpty else { return nil }
        guard let selectedMatchIndex, matches.indices.contains(selectedMatchIndex) else { return matches.count - 1 }
        return (selectedMatchIndex - 1 + matches.count) % matches.count
    }

    /// 编译好的正则缓存。
    ///
    /// 正则的编译不便宜，而查找面板关闭后每次按键仍会触发一次全文档匹配
    /// （见 issue #1279）。缓存让「同一查询词 + 同一选项」只编译一次。
    private static let regularExpressionCache: RegexCache = RegexCache()

    private static func regularExpression(
        for state: EditorFindReplaceState
    ) -> NSRegularExpression? {
        let pattern = state.options.isRegexEnabled
            ? state.findText
            : NSRegularExpression.escapedPattern(for: state.findText)

        let wrappedPattern = state.options.matchesWholeWord
            ? #"\b(?:\#(pattern))\b"#
            : pattern

        let options: NSRegularExpression.Options = state.options.isCaseSensitive ? [] : [.caseInsensitive]
        return regularExpressionCache.expression(
            pattern: wrappedPattern,
            options: options
        )
    }

    /// 正则缓存：有界、按 (pattern, options) 键控。
    private final class RegexCache: @unchecked Sendable {
        private struct Key: Hashable {
            let pattern: String
            /// `NSRegularExpression.Options` 不保证 `Hashable`，用其 rawValue 做键。
            let options: UInt
        }

        private let lock = NSLock()
        private var storage: [Key: NSRegularExpression] = [:]
        private var insertionOrder: [Key] = []
        private let limit = 32

        func expression(
            pattern: String,
            options: NSRegularExpression.Options
        ) -> NSRegularExpression? {
            let key = Key(pattern: pattern, options: options.rawValue)

            lock.lock()
            let cached = storage[key]
            lock.unlock()
            if let cached { return cached }

            guard let compiled = try? NSRegularExpression(pattern: pattern, options: options) else {
                return nil
            }

            lock.lock()
            defer { lock.unlock() }
            if storage[key] == nil {
                insertionOrder.append(key)
            }
            storage[key] = compiled
            if insertionOrder.count > limit {
                let overflow = insertionOrder.count - limit
                for expired in insertionOrder.prefix(overflow) {
                    storage.removeValue(forKey: expired)
                }
                insertionOrder.removeFirst(overflow)
            }
            return compiled
        }
    }

    private static func searchScopes(
        in text: String,
        options: EditorFindReplaceOptions,
        selections: [EditorSelection],
        primarySelection: EditorSelection?
    ) -> [EditorRange] {
        let textLength = (text as NSString).length
        let fullRange = EditorRange(location: 0, length: textLength)
        guard options.inSelectionOnly else { return [fullRange] }

        let nonEmptySelections = selections
            .map(\.range)
            .filter { $0.length > 0 }

        if !nonEmptySelections.isEmpty {
            return normalizedSearchScopes(nonEmptySelections, textLength: textLength)
        }

        if let primarySelection, primarySelection.range.length > 0 {
            return normalizedSearchScopes([primarySelection.range], textLength: textLength)
        }

        return [fullRange]
    }

    private static func normalizedSearchScopes(
        _ ranges: [EditorRange],
        textLength: Int
    ) -> [EditorRange] {
        let sorted = ranges.compactMap { range -> EditorRange? in
            guard range.location >= 0,
                  range.length > 0,
                  range.location <= textLength,
                  range.location <= Int.max - range.length else {
                return nil
            }

            let rawEnd = min(range.location + range.length, textLength)
            guard rawEnd > range.location else { return nil }
            return EditorRange(location: range.location, length: rawEnd - range.location)
        }
        .sorted { lhs, rhs in
            if lhs.location != rhs.location {
                return lhs.location < rhs.location
            }
            return lhs.length < rhs.length
        }

        var merged: [EditorRange] = []
        for range in sorted {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }

            let lastEnd = last.location + last.length
            let rangeEnd = range.location + range.length
            guard range.location <= lastEnd else {
                merged.append(range)
                continue
            }

            merged[merged.count - 1] = EditorRange(
                location: last.location,
                length: max(lastEnd, rangeEnd) - last.location
            )
        }
        return merged
    }

    private static func selectedMatchIndex(
        in matches: [EditorFindMatch],
        preferredRange: EditorRange?,
        primarySelection: EditorSelection?
    ) -> Int? {
        guard !matches.isEmpty else { return nil }

        if let preferredRange,
           let preferredIndex = matches.firstIndex(where: { $0.range == preferredRange }) {
            return preferredIndex
        }

        if let primarySelection {
            let caretLocation = primarySelection.range.location

            if let containingIndex = matches.firstIndex(where: { match in
                match.range.location <= caretLocation && caretLocation <= match.range.location + match.range.length
            }) {
                return containingIndex
            }

            if let nextIndex = matches.firstIndex(where: { $0.range.location >= caretLocation }) {
                return nextIndex
            }
        }

        return 0
    }
}
