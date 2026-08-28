import Foundation

enum MarkdownTableRowParser {
    static func parse(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var cells = split(trimmed)
        if cells.first == "" { cells.removeFirst() }
        if cells.last == "" { cells.removeLast() }

        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func split(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var backslashCount = 0

        for character in line {
            if character == "|" && backslashCount.isMultiple(of: 2) {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }

            if character == "\\" {
                backslashCount += 1
            } else {
                backslashCount = 0
            }
        }

        cells.append(current)
        return cells
    }
}
