import Foundation

public struct MultiCursorState: Equatable, Sendable {
    public var primary: MultiCursorSelection = .init(location: 0, length: 0)
    public var secondary: [MultiCursorSelection] = []

    public var all: [MultiCursorSelection] {
        ([primary] + secondary)
            .filter { $0.location >= 0 && $0.length >= 0 }
            .sorted { $0.location < $1.location }
    }

    public var isEnabled: Bool {
        !secondary.isEmpty
    }

    public init(
        primary: MultiCursorSelection = .init(location: 0, length: 0),
        secondary: [MultiCursorSelection] = []
    ) {
        self.primary = primary
        self.secondary = secondary
    }

    public mutating func clearSecondary() {
        secondary.removeAll()
    }

    public mutating func setPrimary(_ selection: MultiCursorSelection) {
        primary = selection
    }

    public mutating func addSecondary(_ selection: MultiCursorSelection) {
        guard selection.location >= 0, selection.length >= 0 else { return }
        if selection == primary { return }
        if secondary.contains(selection) { return }
        secondary.append(selection)
        secondary.sort { $0.location < $1.location }
    }

    public mutating func replaceAll(_ selections: [MultiCursorSelection]) {
        guard let first = selections.first else { return }
        primary = first
        secondary = Array(selections.dropFirst())
    }
}
