import Foundation

public struct LineEditResult: Equatable, Sendable {
    public let replacementRange: NSRange
    public let replacementText: String
    public let selectedRanges: [NSRange]

    public init(replacementRange: NSRange, replacementText: String, selectedRanges: [NSRange]) {
        self.replacementRange = replacementRange
        self.replacementText = replacementText
        self.selectedRanges = selectedRanges
    }
}

public enum LineEditingController: Sendable {
    public static func deleteLine(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }

        let mergedRanges = mergeOverlappingRanges(lineRanges)
        guard let lastRange = mergedRanges.last else { return nil }
        let totalLength = nsText.length
        let isDeletingToEnd = NSMaxRange(lastRange) >= totalLength

        var replacements: [(range: NSRange, text: String)] = []
        for (index, range) in mergedRanges.enumerated() {
            if index == mergedRanges.count - 1 && isDeletingToEnd {
                let adjustedLocation = max(0, range.location - 1)
                let adjustedRange = NSRange(
                    location: adjustedLocation,
                    length: totalLength - adjustedLocation
                )
                replacements.append((adjustedRange, ""))
            } else {
                replacements.append((range, ""))
            }
        }

        return applyLineEdits(
            text: text,
            replacements: replacements,
            originalSelections: selections,
            cursorBehavior: .lineStart
        )
    }

    public static func copyLineUp(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        copyLine(in: text, selections: selections, direction: .up)
    }

    public static func copyLineDown(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        copyLine(in: text, selections: selections, direction: .down)
    }

    public static func moveLineUp(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        moveLine(in: text, selections: selections, direction: .up)
    }

    public static func moveLineDown(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        moveLine(in: text, selections: selections, direction: .down)
    }

    public static func insertLineBelow(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        var edits: [(range: NSRange, text: String)] = []
        var newCursors: [NSRange] = []

        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            let lineText = nsText.substring(with: lineRange)
            let existingLineEnding = lineEndingSuffix(from: lineText)
            let lineEnding = existingLineEnding ?? preferredLineEnding(in: text)
            let lineContent = stripTrailingLineEnding(from: lineText)
            let indent = String(lineContent.prefix(while: { $0 == " " || $0 == "\t" }))

            let insertLocation = NSMaxRange(lineRange) - ((existingLineEnding as NSString?)?.length ?? 0)
            let newText = lineEnding + indent
            edits.append((range: NSRange(location: insertLocation, length: 0), text: newText))
            newCursors.append(NSRange(location: insertLocation + (newText as NSString).length, length: 0))
        }

        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    public static func insertLineAbove(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        var edits: [(range: NSRange, text: String)] = []
        var newCursors: [NSRange] = []

        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            let lineText = nsText.substring(with: NSRange(
                location: lineRange.location,
                length: min(lineRange.length, nsText.length - lineRange.location)
            ))
            let lineEnding = lineEndingSuffix(from: lineText) ?? preferredLineEnding(in: text)
            let lineContent = stripTrailingLineEnding(from: lineText)
            let indent = String(lineContent.prefix(while: { $0 == " " || $0 == "\t" }))

            let insertLocation = lineRange.location
            let newText = indent + lineEnding
            edits.append((range: NSRange(location: insertLocation, length: 0), text: newText))
            newCursors.append(NSRange(location: insertLocation + (indent as NSString).length, length: 0))
        }

        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    public static func sortLines(
        in text: String,
        selections: [NSRange],
        descending: Bool
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText),
              let selection = selections.first,
              selection.length > 0 else { return nil }

        let lineRange = nsText.lineRange(for: selection)
        let selectedText = nsText.substring(with: lineRange)

        let lineEnding = preferredLineEnding(in: selectedText)
        var lines = selectedText.components(separatedBy: lineEnding)
        let trailingLineEnding = lineEndingSuffix(from: selectedText)
        if trailingLineEnding != nil && lines.last == "" {
            lines.removeLast()
        }

        guard lines.count > 1 else { return nil }

        if descending {
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        } else {
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        let sortedText = lines.joined(separator: lineEnding) + (trailingLineEnding ?? "")
        let newSelectionLength = (sortedText as NSString).length

        return LineEditResult(
            replacementRange: lineRange,
            replacementText: sortedText,
            selectedRanges: [NSRange(location: lineRange.location, length: newSelectionLength)]
        )
    }

    public static func transpose(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard let selection = selections.first,
              selection.length == 0,
              selection.location > 0,
              selection.location < nsText.length else { return nil }

        let location = selection.location
        let before = nsText.substring(with: NSRange(location: location - 1, length: 1))
        let after = nsText.substring(with: NSRange(location: location, length: 1))

        if !isLineEndingCharacter(before) && !isLineEndingCharacter(after) {
            let swapped = after + before
            return LineEditResult(
                replacementRange: NSRange(location: location - 1, length: 2),
                replacementText: swapped,
                selectedRanges: [NSRange(location: location + 1, length: 0)]
            )
        }

        return nil
    }

    public static func toggleLineComment(
        in text: String,
        selections: [NSRange],
        commentPrefix: String
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        let prefix = commentPrefix
        let prefixLength = (prefix as NSString).length
        var allLineStarts: Set<Int> = []
        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            var pos = lineRange.location
            while pos < NSMaxRange(lineRange) && pos < nsText.length {
                allLineStarts.insert(pos)
                let currentLineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
                pos = NSMaxRange(currentLineRange)
                if pos <= currentLineRange.location { break }
            }
        }

        let sortedLineStarts = allLineStarts.sorted()
        let allCommented = sortedLineStarts.allSatisfy { lineStart in
            guard lineStart + prefixLength <= nsText.length else { return false }
            let linePrefix = nsText.substring(with: NSRange(location: lineStart, length: prefixLength))
            if linePrefix.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return linePrefix.hasPrefix(prefix)
        }

        var replacements: [(range: NSRange, text: String)] = []
        for lineStart in sortedLineStarts {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            let lineEnd = min(NSMaxRange(lineRange), nsText.length)
            var lineText = nsText.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))

            if allCommented {
                if lineText.hasPrefix(prefix + " ") {
                    lineText = String(lineText.dropFirst(prefixLength + 1))
                } else if lineText.hasPrefix(prefix) {
                    lineText = String(lineText.dropFirst(prefixLength))
                }
            } else if !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lineText = prefix + " " + lineText
            }

            replacements.append((range: NSRange(location: lineStart, length: lineEnd - lineStart), text: lineText))
        }

        return applyLineEdits(
            text: text,
            replacements: replacements,
            originalSelections: selections,
            cursorBehavior: .preserve
        )
    }

    public static func fullLineRange(for selection: NSRange, in nsText: NSString) -> NSRange {
        nsText.lineRange(for: selection)
    }

    public static func mergeOverlappingRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.location < $1.location }

        var merged: [NSRange] = [sorted[0]]
        for range in sorted.dropFirst() {
            guard let last = merged.last else { continue }
            if range.location <= NSMaxRange(last) {
                let newEnd = max(NSMaxRange(last), NSMaxRange(range))
                merged[merged.count - 1] = NSRange(
                    location: last.location,
                    length: newEnd - last.location
                )
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    static func rangesAreContiguous(_ ranges: [NSRange]) -> Bool {
        guard ranges.count > 1 else { return true }
        for (previous, current) in zip(ranges, ranges.dropFirst()) {
            if current.location != NSMaxRange(previous) {
                return false
            }
        }
        return true
    }

    private enum CopyDirection {
        case up, down
    }

    private enum MoveDirection {
        case up, down
    }

    private enum CursorBehavior {
        case lineStart
        case preserve
    }

    private static func copyLine(
        in text: String,
        selections: [NSRange],
        direction: CopyDirection
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }
        let mergedRanges = mergeOverlappingRanges(lineRanges)

        var copiedTexts: [String] = []
        for range in mergedRanges {
            copiedTexts.append(nsText.substring(with: range))
        }

        var edits: [(range: NSRange, text: String)] = []
        var cursorPlans: [(sourceRange: NSRange, destinationStart: Int, contentLength: Int)] = []

        for (index, range) in mergedRanges.enumerated() {
            let lineText = copiedTexts[index]
            let insertText: String
            let insertLocation: Int
            let lineEnding = lineEndingSuffix(from: lineText)
            let fallbackLineEnding = preferredLineEnding(in: text)
            let lineContentLength = (lineText as NSString).length - ((lineEnding as NSString?)?.length ?? 0)
            let destinationStart: Int

            if lineEnding != nil {
                switch direction {
                case .up:
                    insertText = lineText
                    insertLocation = range.location
                    destinationStart = insertLocation
                case .down:
                    insertText = lineText
                    insertLocation = NSMaxRange(range)
                    destinationStart = insertLocation
                }
            } else {
                switch direction {
                case .up:
                    insertText = lineText + fallbackLineEnding
                    insertLocation = range.location
                    destinationStart = insertLocation
                case .down:
                    insertText = fallbackLineEnding + lineText
                    insertLocation = NSMaxRange(range)
                    destinationStart = insertLocation + (fallbackLineEnding as NSString).length
                }
            }

            edits.append((range: NSRange(location: insertLocation, length: 0), text: insertText))
            cursorPlans.append((
                sourceRange: range,
                destinationStart: destinationStart,
                contentLength: max(lineContentLength, 0)
            ))
        }

        let newCursors = selections.compactMap { selection -> NSRange? in
            guard let plan = cursorPlans.first(where: {
                selection.location >= $0.sourceRange.location && selection.location <= NSMaxRange($0.sourceRange)
            }) else {
                return nil
            }
            let offset = selection.location - plan.sourceRange.location
            return NSRange(
                location: plan.destinationStart + min(offset, plan.contentLength),
                length: selection.length
            )
        }
        guard newCursors.count == selections.count else { return nil }

        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    private static func moveLine(
        in text: String,
        selections: [NSRange],
        direction: MoveDirection
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard validSelections(selections, in: nsText) else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }
        let mergedRanges = mergeOverlappingRanges(lineRanges)
        guard rangesAreContiguous(mergedRanges) else { return nil }

        switch direction {
        case .up:
            guard let firstRange = mergedRanges.first,
                  firstRange.location > 0 else { return nil }

            let aboveLineRange = nsText.lineRange(for: NSRange(location: firstRange.location - 1, length: 0))
            guard let lastRange = mergedRanges.last else { return nil }
            let swapRange = NSRange(
                location: aboveLineRange.location,
                length: NSMaxRange(lastRange) - aboveLineRange.location
            )

            let aboveText = nsText.substring(with: aboveLineRange)
            let blockText = mergedRanges.map { nsText.substring(with: $0) }.joined()
            let lineEnding = lineEndingSuffix(from: blockText)
                ?? lineEndingSuffix(from: aboveText)
                ?? preferredLineEnding(in: text)
            let aboveContent = stripTrailingLineEnding(from: aboveText)
            let blockContent = stripTrailingLineEnding(from: blockText)
            let newText = blockContent + lineEnding + aboveContent

            guard let firstRange = mergedRanges.first else { return nil }
            let newCursors = selections.map { selection in
                let offset = selection.location - firstRange.location
                let newLocation = swapRange.location + min(offset, max((blockContent as NSString).length, 0))
                return NSRange(location: newLocation, length: selection.length)
            }

            let replacedText = replacing(text: text, range: swapRange, with: newText)
            return LineEditResult(
                replacementRange: NSRange(location: 0, length: nsText.length),
                replacementText: replacedText,
                selectedRanges: newCursors
            )

        case .down:
            guard let lastRange = mergedRanges.last,
                  NSMaxRange(lastRange) < nsText.length else { return nil }
            guard let firstRange = mergedRanges.first else { return nil }

            let belowLineStart = NSMaxRange(lastRange)
            let belowLineRange = nsText.lineRange(for: NSRange(location: belowLineStart, length: 0))
            let swapRange = NSRange(
                location: firstRange.location,
                length: NSMaxRange(belowLineRange) - firstRange.location
            )

            let blockText = mergedRanges.map { nsText.substring(with: $0) }.joined()
            let belowText = nsText.substring(with: belowLineRange)
            let lineEnding = lineEndingSuffix(from: belowText)
                ?? lineEndingSuffix(from: blockText)
                ?? preferredLineEnding(in: text)
            let blockContent = stripTrailingLineEnding(from: blockText)
            let belowContent = stripTrailingLineEnding(from: belowText)
            let trailingLineEnding = lineEndingSuffix(from: belowText) ?? ""
            let newText = belowContent + lineEnding + blockContent + trailingLineEnding

            let blockSize = (blockContent as NSString).length
            let movedBlockStart = swapRange.location + (belowContent as NSString).length + (lineEnding as NSString).length

            guard let firstRange = mergedRanges.first else { return nil }
            let newCursors = selections.map { selection in
                let offset = selection.location - firstRange.location
                let newLocation = movedBlockStart + min(offset, max(blockSize - 1, 0))
                return NSRange(location: newLocation, length: selection.length)
            }

            let replacedText = replacing(text: text, range: swapRange, with: newText)
            return LineEditResult(
                replacementRange: NSRange(location: 0, length: nsText.length),
                replacementText: replacedText,
                selectedRanges: newCursors
            )
        }
    }

    private static func applyLineEdits(
        text: String,
        replacements: [(range: NSRange, text: String)],
        originalSelections: [NSRange],
        cursorBehavior: CursorBehavior
    ) -> LineEditResult? {
        guard !replacements.isEmpty else { return nil }

        let nsText = text as NSString
        guard let firstRange = replacements.first,
              let lastRange = replacements.last
        else { return nil }
        let totalRange = NSRange(
            location: firstRange.range.location,
            length: NSMaxRange(lastRange.range) - firstRange.range.location
        )

        var result = ""
        if totalRange.location > 0 {
            result += nsText.substring(with: NSRange(location: 0, length: totalRange.location))
        }

        var segments: [(offset: Int, length: Int, replacement: String)] = []
        for replacement in replacements {
            segments.append((
                offset: replacement.range.location - totalRange.location,
                length: replacement.range.length,
                replacement: replacement.text
            ))
        }

        var reconstructed = ""
        var currentPos = 0
        for segment in segments {
            if segment.offset > currentPos {
                let rangeInSegment = NSRange(
                    location: totalRange.location + currentPos,
                    length: segment.offset - currentPos
                )
                if NSMaxRange(rangeInSegment) <= nsText.length {
                    reconstructed += nsText.substring(with: rangeInSegment)
                }
            }
            reconstructed += segment.replacement
            currentPos = segment.offset + segment.length
        }

        if currentPos < totalRange.length {
            let remainingStart = totalRange.location + currentPos
            let remainingLength = totalRange.length - currentPos
            if remainingStart + remainingLength <= nsText.length {
                reconstructed += nsText.substring(with: NSRange(
                    location: remainingStart,
                    length: remainingLength
                ))
            }
        }

        result += reconstructed

        let afterTotalRange = NSMaxRange(totalRange)
        if afterTotalRange < nsText.length {
            result += nsText.substring(with: NSRange(
                location: afterTotalRange,
                length: nsText.length - afterTotalRange
            ))
        }

        let newCursors: [NSRange]
        switch cursorBehavior {
        case .lineStart:
            newCursors = originalSelections.map { _ in
                NSRange(location: totalRange.location, length: 0)
            }
        case .preserve:
            newCursors = originalSelections
        }

        return LineEditResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: result,
            selectedRanges: newCursors
        )
    }

    private static func validSelections(_ selections: [NSRange], in nsText: NSString) -> Bool {
        guard !selections.isEmpty else { return false }
        return selections.allSatisfy { selection in
            guard selection.location >= 0, selection.length >= 0 else { return false }
            guard selection.location <= nsText.length else { return false }
            guard selection.location <= Int.max - selection.length else { return false }
            return selection.location + selection.length <= nsText.length
        }
    }

    private static func applyEditsFromBack(
        text: String,
        edits: [(range: NSRange, text: String)],
        newCursors: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !edits.isEmpty else { return nil }

        var mutableText = text
        let sortedEdits = edits.sorted { $0.range.location > $1.range.location }

        for edit in sortedEdits {
            let range = edit.range
            guard let stringRange = Range(range, in: mutableText) else { return nil }

            if range.length == 0 {
                mutableText.insert(contentsOf: edit.text, at: stringRange.lowerBound)
            } else {
                mutableText.replaceSubrange(stringRange, with: edit.text)
            }
        }

        return LineEditResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: mutableText,
            selectedRanges: newCursors
        )
    }

    private static func lineEndingSuffix(from text: String) -> String? {
        if text.hasSuffix("\r\n") { return "\r\n" }
        if text.hasSuffix("\n") { return "\n" }
        if text.hasSuffix("\r") { return "\r" }
        return nil
    }

    private static func stripTrailingLineEnding(from text: String) -> String {
        guard let suffix = lineEndingSuffix(from: text) else { return text }
        return String(text.dropLast(suffix.count))
    }

    private static func preferredLineEnding(in text: String) -> String {
        if text.contains("\r\n") { return "\r\n" }
        if text.contains("\n") { return "\n" }
        if text.contains("\r") { return "\r" }
        return "\n"
    }

    private static func isLineEndingCharacter(_ text: String) -> Bool {
        text == "\n" || text == "\r"
    }

    private static func replacing(text: String, range: NSRange, with replacement: String) -> String {
        let nsText = text as NSString
        let prefix = nsText.substring(to: range.location)
        let suffixStart = NSMaxRange(range)
        let suffix = suffixStart < nsText.length ? nsText.substring(from: suffixStart) : ""
        return prefix + replacement + suffix
    }
}
