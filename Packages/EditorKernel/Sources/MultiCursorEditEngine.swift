import Foundation

public enum MultiCursorOperation: Sendable {
    case replaceSelection(String)
    case insert(String)
    case deleteBackward
    case indent(String)
    case outdent(tabSize: Int, useSpaces: Bool)
}

public struct MultiCursorEditResult: Equatable, Sendable {
    public let text: String
    public let selections: [MultiCursorSelection]

    public init(text: String, selections: [MultiCursorSelection]) {
        self.text = text
        self.selections = selections
    }
}

public enum MultiCursorEditEngine {
    public static func apply(
        text: String,
        selections: [MultiCursorSelection],
        operation: MultiCursorOperation
    ) -> MultiCursorEditResult {
        guard !selections.isEmpty else {
            return .init(text: text, selections: [])
        }

        var buffer = text
        let ns = NSMutableString(string: buffer)
        let ordered = selections
            .map { normalized($0, maxLength: ns.length) }
            .sorted { $0.location > $1.location }

        if case .indent(let indentUnit) = operation {
            return applyIndent(
                text: text,
                selections: selections,
                indentUnit: indentUnit
            )
        }

        if case .outdent(let tabSize, let useSpaces) = operation {
            return applyOutdent(
                text: text,
                selections: selections,
                tabSize: tabSize,
                useSpaces: useSpaces
            )
        }

        var appliedEdits: [(range: NSRange, replacementLength: Int)] = []
        var selectionRecords: [(selection: MultiCursorSelection, sourceEditIndex: Int?)] = []

        for sel in ordered {
            let safe = normalized(sel, maxLength: ns.length)
            switch operation {
            case .replaceSelection(let content):
                let editIndex = appliedEdits.count
                appliedEdits.append((
                    range: NSRange(location: safe.location, length: safe.length),
                    replacementLength: (content as NSString).length
                ))
                ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                selectionRecords.append((
                    selection: .init(location: safe.location + (content as NSString).length, length: 0),
                    sourceEditIndex: editIndex
                ))

            case .insert(let content):
                let editIndex = appliedEdits.count
                let replacementLength = (content as NSString).length
                if safe.length > 0 {
                    appliedEdits.append((
                        range: NSRange(location: safe.location, length: safe.length),
                        replacementLength: replacementLength
                    ))
                    ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                    selectionRecords.append((
                        selection: .init(location: safe.location + replacementLength, length: 0),
                        sourceEditIndex: editIndex
                    ))
                } else {
                    appliedEdits.append((
                        range: NSRange(location: safe.location, length: 0),
                        replacementLength: replacementLength
                    ))
                    ns.insert(content, at: safe.location)
                    selectionRecords.append((
                        selection: .init(location: safe.location + replacementLength, length: 0),
                        sourceEditIndex: editIndex
                    ))
                }

            case .deleteBackward:
                if safe.length > 0 {
                    let editIndex = appliedEdits.count
                    appliedEdits.append((
                        range: NSRange(location: safe.location, length: safe.length),
                        replacementLength: 0
                    ))
                    ns.deleteCharacters(in: NSRange(location: safe.location, length: safe.length))
                    selectionRecords.append((
                        selection: .init(location: safe.location, length: 0),
                        sourceEditIndex: editIndex
                    ))
                } else if safe.location > 0 {
                    let editIndex = appliedEdits.count
                    appliedEdits.append((
                        range: NSRange(location: safe.location - 1, length: 1),
                        replacementLength: 0
                    ))
                    ns.deleteCharacters(in: NSRange(location: safe.location - 1, length: 1))
                    selectionRecords.append((
                        selection: .init(location: safe.location - 1, length: 0),
                        sourceEditIndex: editIndex
                    ))
                } else {
                    selectionRecords.append((selection: safe, sourceEditIndex: nil))
                }

            case .indent, .outdent:
                break
            }
        }

        buffer = ns as String
        let finalLength = (buffer as NSString).length
        let adjustedSelections = selectionRecords
            .map {
                adjustedSelection(
                    $0.selection,
                    sourceEditIndex: $0.sourceEditIndex,
                    appliedEdits: appliedEdits,
                    finalLength: finalLength
                )
            }
            .sorted { $0.location < $1.location }
        return .init(text: buffer, selections: adjustedSelections)
    }

    private static func applyIndent(
        text: String,
        selections: [MultiCursorSelection],
        indentUnit: String
    ) -> MultiCursorEditResult {
        let nsText = text as NSString
        let lineStarts = uniqueLineStarts(in: nsText, selections: selections)
        guard !lineStarts.isEmpty else {
            return .init(text: text, selections: selections.sorted { $0.location < $1.location })
        }

        let buffer = NSMutableString(string: text)
        let indentLength = (indentUnit as NSString).length

        for start in lineStarts.sorted(by: >) {
            buffer.insert(indentUnit, at: start)
        }

        let adjustedSelections = selections
            .map { normalized($0, maxLength: nsText.length) }
            .map { adjustedSelection($0, forInsertedLineStarts: lineStarts, indentLength: indentLength) }
            .sorted { $0.location < $1.location }

        return .init(text: buffer as String, selections: adjustedSelections)
    }

    private static func applyOutdent(
        text: String,
        selections: [MultiCursorSelection],
        tabSize: Int,
        useSpaces: Bool
    ) -> MultiCursorEditResult {
        let nsText = text as NSString
        let lineStarts = uniqueLineStarts(in: nsText, selections: selections)
        guard !lineStarts.isEmpty else {
            return .init(text: text, selections: selections.sorted { $0.location < $1.location })
        }

        let buffer = NSMutableString(string: text)
        var removedRanges: [NSRange] = []

        for start in lineStarts.sorted(by: >) {
            let lineRange = nsText.lineRange(for: NSRange(location: start, length: 0))
            let lineText = nsText.substring(with: lineRange)
            let removeWidth = outdentWidth(lineText: lineText, tabSize: tabSize, useSpaces: useSpaces)
            guard removeWidth > 0 else { continue }
            let removeRange = NSRange(location: start, length: removeWidth)
            buffer.deleteCharacters(in: removeRange)
            removedRanges.append(removeRange)
        }

        let adjustedSelections = selections
            .map { normalized($0, maxLength: nsText.length) }
            .map { adjustedSelection($0, removedRanges: removedRanges) }
            .sorted { $0.location < $1.location }

        return .init(text: buffer as String, selections: adjustedSelections)
    }

    private static func normalized(_ selection: MultiCursorSelection, maxLength: Int) -> MultiCursorSelection {
        let location = min(max(selection.location, 0), maxLength)
        let upperBound = min(max(selection.upperBound, location), maxLength)
        return .init(location: location, length: upperBound - location)
    }

    private static func uniqueLineStarts(
        in nsText: NSString,
        selections: [MultiCursorSelection]
    ) -> [Int] {
        var result = Set<Int>()
        for selection in selections {
            let safe = normalized(selection, maxLength: nsText.length)
            let effectiveLength = max(safe.length, safe.isCaret ? 1 : 0)
            let lineRange = nsText.lineRange(for: NSRange(location: min(safe.location, max(nsText.length - 1, 0)), length: 0))
            if safe.isCaret || lineRange.length == 0 {
                result.insert(lineRange.location)
                continue
            }

            let searchRange = NSRange(location: safe.location, length: effectiveLength)
            nsText.enumerateSubstrings(
                in: searchRange,
                options: [.byLines, .substringNotRequired]
            ) { _, substringRange, _, _ in
                result.insert(substringRange.location)
            }
        }
        return Array(result)
    }

    private static func adjustedSelection(
        _ selection: MultiCursorSelection,
        forInsertedLineStarts lineStarts: [Int],
        indentLength: Int
    ) -> MultiCursorSelection {
        if selection.isCaret {
            let insertedBeforeOrAtCaret = lineStarts.filter { $0 <= selection.location }.count * indentLength
            return MultiCursorSelection(location: selection.location + insertedBeforeOrAtCaret, length: 0)
        }

        let insertedBeforeStart = lineStarts.filter { $0 < selection.location }.count * indentLength
        let insertedBeforeEnd = lineStarts.filter { $0 < selection.upperBound }.count * indentLength
        let location = selection.location + insertedBeforeStart
        let upperBound = selection.upperBound + insertedBeforeEnd
        return MultiCursorSelection(
            location: location,
            length: max(0, upperBound - location)
        )
    }

    private static func outdentWidth(
        lineText: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> Int {
        let nsLine = lineText as NSString
        guard nsLine.length > 0 else { return 0 }

        if useSpaces {
            let maxWidth = min(tabSize, nsLine.length)
            var count = 0
            while count < maxWidth, nsLine.character(at: count) == 32 {
                count += 1
            }
            return count
        }

        if nsLine.character(at: 0) == 9 {
            return 1
        }
        return 0
    }

    private static func adjustedSelection(
        _ selection: MultiCursorSelection,
        removedRanges: [NSRange]
    ) -> MultiCursorSelection {
        let originalEnd = selection.location + selection.length
        let startShift = removedRanges
            .filter { $0.location < selection.location }
            .reduce(0) { $0 + $1.length }

        let endShift = removedRanges
            .filter { $0.location < originalEnd }
            .reduce(0) { $0 + $1.length }

        let newLocation = max(0, selection.location - startShift)
        let newEnd = max(newLocation, originalEnd - endShift)
        return .init(location: newLocation, length: newEnd - newLocation)
    }

    private static func adjustedSelection(
        _ selection: MultiCursorSelection,
        sourceEditIndex: Int?,
        appliedEdits: [(range: NSRange, replacementLength: Int)],
        finalLength: Int
    ) -> MultiCursorSelection {
        func shifted(_ position: Int) -> Int {
            let shiftedPosition = appliedEdits.enumerated().reduce(position) { result, item in
                let (index, edit) = item
                guard index != sourceEditIndex, edit.range.location < position else {
                    return result
                }
                return result + edit.replacementLength - edit.range.length
            }
            return min(max(shiftedPosition, 0), finalLength)
        }

        let location = shifted(selection.location)
        let upperBound = shifted(selection.upperBound)
        return .init(
            location: min(location, upperBound),
            length: abs(upperBound - location)
        )
    }
}
