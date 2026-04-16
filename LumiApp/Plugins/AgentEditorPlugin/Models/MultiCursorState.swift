import Foundation

/// 多光标选择范围
struct MultiCursorSelection: Hashable {
    var location: Int
    var length: Int

    var isCaret: Bool { length == 0 }
    var upperBound: Int { location + length }
}

/// 多光标编辑状态
struct MultiCursorState {
    var primary: MultiCursorSelection = .init(location: 0, length: 0)
    var secondary: [MultiCursorSelection] = []

    var all: [MultiCursorSelection] {
        ([primary] + secondary)
            .filter { $0.location >= 0 && $0.length >= 0 }
            .sorted { $0.location < $1.location }
    }

    var isEnabled: Bool {
        !secondary.isEmpty
    }

    mutating func clearSecondary() {
        secondary.removeAll()
    }

    mutating func setPrimary(_ selection: MultiCursorSelection) {
        primary = selection
    }

    mutating func addSecondary(_ selection: MultiCursorSelection) {
        guard selection.location >= 0, selection.length >= 0 else { return }
        if selection == primary { return }
        if secondary.contains(selection) { return }
        secondary.append(selection)
        secondary.sort { $0.location < $1.location }
    }

    mutating func replaceAll(_ selections: [MultiCursorSelection]) {
        guard let first = selections.first else { return }
        primary = first
        secondary = Array(selections.dropFirst())
    }
}
