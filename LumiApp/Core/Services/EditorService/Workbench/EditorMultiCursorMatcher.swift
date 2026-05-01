import Foundation

enum EditorMultiCursorMatcher {
    static func selectionText(
        for range: NSRange,
        in text: NSString
    ) -> String? {
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return nil }
        return text.substring(with: range)
    }

    static func selectionText(
        for selection: MultiCursorSelection,
        in text: NSString
    ) -> String? {
        let range = nsRange(from: selection)
        return selectionText(for: range, in: text)
    }

    static func normalizedRange(
        _ range: NSRange,
        in text: NSString
    ) -> NSRange {
        guard range.location != NSNotFound else { return NSRange(location: NSNotFound, length: 0) }
        let location = min(max(range.location, 0), text.length)
        let length = min(max(range.length, 0), max(0, text.length - location))
        return NSRange(location: location, length: length)
    }

    static func resolvedBaseSelection(
        from range: NSRange,
        in text: NSString
    ) -> MultiCursorSelection? {
        if range.length > 0 {
            return MultiCursorSelection(location: range.location, length: range.length)
        }

        guard let wordRange = wordRange(at: range.location, in: text), wordRange.length > 0 else {
            return nil
        }
        return MultiCursorSelection(location: wordRange.location, length: wordRange.length)
    }

    static func searchContext(
        from range: NSRange,
        in text: NSString
    ) -> EditorMultiCursorSearchContext? {
        guard let baseSelection = resolvedBaseSelection(from: range, in: text),
              let query = selectionText(for: baseSelection, in: text),
              !query.isEmpty else {
            return nil
        }

        return EditorMultiCursorSearchContext(
            baseSelection: baseSelection,
            query: query
        )
    }

    static func ranges(
        of needle: String,
        in text: NSString
    ) -> [MultiCursorSelection] {
        guard !needle.isEmpty else { return [] }

        var result: [MultiCursorSelection] = []
        var searchLocation = 0
        let needleLength = (needle as NSString).length
        let shouldMatchWholeWord = isWholeWordSelection(needle)

        while searchLocation <= text.length - needleLength {
            let searchRange = NSRange(location: searchLocation, length: text.length - searchLocation)
            let found = text.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else { break }

            let selection = MultiCursorSelection(location: found.location, length: found.length)
            if !shouldMatchWholeWord || isWholeWordMatch(selection, in: text) {
                result.append(selection)
            }

            searchLocation = found.location + max(found.length, 1)
        }

        return result
    }

    private static func wordRange(
        at location: Int,
        in text: NSString
    ) -> NSRange? {
        guard text.length > 0 else { return nil }
        let clampedLocation = min(max(location, 0), text.length)

        var pivot = clampedLocation
        if pivot == text.length {
            pivot = max(text.length - 1, 0)
        }
        if !isWordCharacter(at: pivot, in: text), clampedLocation > 0, isWordCharacter(at: clampedLocation - 1, in: text) {
            pivot = clampedLocation - 1
        }
        guard isWordCharacter(at: pivot, in: text) else { return nil }

        var start = pivot
        var end = pivot
        while start > 0, isWordCharacter(at: start - 1, in: text) {
            start -= 1
        }
        while end + 1 < text.length, isWordCharacter(at: end + 1, in: text) {
            end += 1
        }
        return NSRange(location: start, length: end - start + 1)
    }

    private static func isWholeWordSelection(_ text: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isWholeWordMatch(
        _ selection: MultiCursorSelection,
        in text: NSString
    ) -> Bool {
        let lowerIndex = selection.location - 1
        let upperIndex = selection.upperBound
        return !isWordCharacter(at: lowerIndex, in: text) && !isWordCharacter(at: upperIndex, in: text)
    }

    private static func isWordCharacter(
        at index: Int,
        in text: NSString
    ) -> Bool {
        guard index >= 0, index < text.length else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let scalar = text.substring(with: NSRange(location: index, length: 1)).unicodeScalars.first
        return scalar.map { allowed.contains($0) } ?? false
    }

    private static func nsRange(from selection: MultiCursorSelection) -> NSRange {
        NSRange(location: selection.location, length: selection.length)
    }
}
