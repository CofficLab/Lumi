import Foundation

enum MultiCursorOperation {
    case replaceSelection(String)
    case insert(String)
    case deleteBackward
    case indent(String)
    case outdent(tabSize: Int, useSpaces: Bool)
}

struct MultiCursorEditResult {
    let text: String
    let selections: [MultiCursorSelection]
}

/// 多光标编辑引擎
/// 以“从后往前”顺序应用编辑，避免前序编辑导致后续 range 偏移
enum MultiCursorEditEngine {

    static func apply(
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

        var newSelections: [MultiCursorSelection] = []

        for sel in ordered {
            let safe = normalized(sel, maxLength: ns.length)
            switch operation {
            case .replaceSelection(let content):
                ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))

            case .insert(let content):
                if safe.length > 0 {
                    ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                    newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))
                } else {
                    ns.insert(content, at: safe.location)
                    newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))
                }

            case .deleteBackward:
                if safe.length > 0 {
                    ns.deleteCharacters(in: NSRange(location: safe.location, length: safe.length))
                    newSelections.append(.init(location: safe.location, length: 0))
                } else if safe.location > 0 {
                    ns.deleteCharacters(in: NSRange(location: safe.location - 1, length: 1))
                    newSelections.append(.init(location: safe.location - 1, length: 0))
                } else {
                    newSelections.append(safe)
                }
            case .indent, .outdent:
                break
            }
        }

        buffer = ns as String
        return .init(text: buffer, selections: newSelections.sorted { $0.location < $1.location })
    }

    private static func applyIndent(
        text: String,
        selections: [MultiCursorSelection],
        indentUnit: String
    ) -> MultiCursorEditResult {
        let ns = text as NSString
        let normalizedSelections = selections
            .map { normalized($0, maxLength: ns.length) }
            .sorted { $0.location < $1.location }

        let lineStarts = uniqueLineStarts(in: text, selections: normalizedSelections)
        let lineStartSet = Set(lineStarts)
        let replacements = lineStarts.sorted(by: >)
        let mutable = NSMutableString(string: text)
        for start in replacements {
            mutable.insert(indentUnit, at: start)
        }

        let indentLength = (indentUnit as NSString).length
        let updatedSelections = normalizedSelections.map { selection in
            let shiftBeforeStart = replacements.filter { $0 < selection.location }.count * indentLength
            let coveredStarts = lineStartSet.filter { lineStart in
                lineStart >= selection.location && lineStart < selection.location + selection.length
            }.count

            return MultiCursorSelection(
                location: selection.location + shiftBeforeStart,
                length: selection.length + coveredStarts * indentLength
            )
        }

        return .init(text: mutable as String, selections: updatedSelections)
    }

    private static func applyOutdent(
        text: String,
        selections: [MultiCursorSelection],
        tabSize: Int,
        useSpaces: Bool
    ) -> MultiCursorEditResult {
        let ns = text as NSString
        let normalizedSelections = selections
            .map { normalized($0, maxLength: ns.length) }
            .sorted { $0.location < $1.location }

        let lineStarts = uniqueLineStarts(in: text, selections: normalizedSelections)
        let removals = lineStarts.compactMap { lineStart -> NSRange? in
            let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            let lineText = ns.substring(with: lineRange)
            let length = outdentWidth(in: lineText, tabSize: tabSize, useSpaces: useSpaces)
            guard length > 0 else { return nil }
            return NSRange(location: lineStart, length: length)
        }

        guard !removals.isEmpty else {
            return .init(text: text, selections: normalizedSelections)
        }

        let mutable = NSMutableString(string: text)
        for removal in removals.sorted(by: { $0.location > $1.location }) {
            mutable.deleteCharacters(in: removal)
        }

        let updatedSelections = normalizedSelections.map { selection in
            adjustedSelection(selection, removedRanges: removals)
        }

        return .init(text: mutable as String, selections: updatedSelections)
    }

    private static func normalized(_ selection: MultiCursorSelection, maxLength: Int) -> MultiCursorSelection {
        let location = min(max(0, selection.location), maxLength)
        let maxSelectable = max(0, maxLength - location)
        let length = min(max(0, selection.length), maxSelectable)
        return .init(location: location, length: length)
    }

    private static func uniqueLineStarts(
        in text: String,
        selections: [MultiCursorSelection]
    ) -> [Int] {
        let ns = text as NSString
        var starts: Set<Int> = []

        for selection in selections {
            let first = ns.lineRange(for: NSRange(location: selection.location, length: 0)).location
            let lastLocation = selection.length > 0
                ? max(selection.location, selection.location + selection.length - 1)
                : selection.location
            let last = ns.lineRange(for: NSRange(location: min(lastLocation, ns.length), length: 0)).location

            var current = first
            while current <= last, current < ns.length {
                starts.insert(current)
                let lineRange = ns.lineRange(for: NSRange(location: current, length: 0))
                let next = NSMaxRange(lineRange)
                if next <= current { break }
                current = next
            }

            if ns.length == 0 || first == ns.length {
                starts.insert(first)
            }
        }

        return starts.sorted()
    }

    private static func outdentWidth(
        in lineText: String,
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
}
