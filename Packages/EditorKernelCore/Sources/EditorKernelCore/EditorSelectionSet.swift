import Foundation

public struct EditorSelectionSet: Equatable, Sendable {
    public let selections: [EditorSelection]

    public var primary: EditorSelection? {
        selections.first
    }

    public var count: Int {
        selections.count
    }

    public var isEmpty: Bool {
        selections.isEmpty
    }

    public var isMultiCursor: Bool {
        selections.count > 1
    }

    public static let initial = EditorSelectionSet(selections: [
        EditorSelection(range: EditorRange(location: 0, length: 0))
    ])

    public init(selections: [EditorSelection]) {
        if selections.isEmpty {
            self.selections = [EditorSelection(range: EditorRange(location: 0, length: 0))]
        } else {
            self.selections = selections.sorted {
                if $0.range.location != $1.range.location {
                    return $0.range.location < $1.range.location
                }
                return $0.range.length < $1.range.length
            }
        }
    }

    public init(multiCursorSelections: [MultiCursorSelection]) {
        let mapped = multiCursorSelections
            .filter { $0.location >= 0 }
            .sorted { $0.location < $1.location }
            .map { EditorSelection(range: EditorRange(location: $0.location, length: $0.length)) }
        self.init(selections: mapped)
    }

    public func replacingAll(_ newSelections: [EditorSelection]) -> EditorSelectionSet {
        EditorSelectionSet(selections: newSelections)
    }

    public func replacingPrimary(_ newPrimary: EditorSelection) -> EditorSelectionSet {
        guard !selections.isEmpty else {
            return EditorSelectionSet(selections: [newPrimary])
        }
        var updated = selections
        updated[0] = newPrimary
        return EditorSelectionSet(selections: updated)
    }

    public func addingSelection(_ selection: EditorSelection) -> EditorSelectionSet {
        var updated = selections
        updated.append(selection)
        updated.sort { $0.range.location < $1.range.location }
        return EditorSelectionSet(selections: updated)
    }

    public func removingLastSecondary() -> EditorSelectionSet {
        guard selections.count > 1 else { return self }
        var updated = selections
        updated.removeLast()
        return EditorSelectionSet(selections: updated)
    }

    public func clearingSecondary() -> EditorSelectionSet {
        guard let primary else { return .initial }
        return EditorSelectionSet(selections: [primary])
    }

    public func toMultiCursorSelections() -> [MultiCursorSelection] {
        selections.map {
            MultiCursorSelection(location: $0.range.location, length: $0.range.length)
        }
    }
}
