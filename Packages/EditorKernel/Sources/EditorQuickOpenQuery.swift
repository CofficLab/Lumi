import Foundation

@MainActor
public enum EditorQuickOpenQueryScope: Equatable {
    case files
    case documentSymbols
    case workspaceSymbols
    case line
    case commands
}

@MainActor
public struct EditorQuickOpenQuery: Equatable {
    public let rawText: String
    public let scope: EditorQuickOpenQueryScope
    public let searchText: String
    public let line: Int?
    public let column: Int?
    public let hasExplicitScope: Bool

    public init(
        rawText: String,
        scope: EditorQuickOpenQueryScope,
        searchText: String,
        line: Int?,
        column: Int?,
        hasExplicitScope: Bool
    ) {
        self.rawText = rawText
        self.scope = scope
        self.searchText = searchText
        self.line = line
        self.column = column
        self.hasExplicitScope = hasExplicitScope
    }
}

@MainActor
public enum EditorQuickOpenQueryParser {
    public static func parse(_ rawQuery: String) -> EditorQuickOpenQuery {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = trimmed.first else {
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .files,
                searchText: "",
                line: nil,
                column: nil,
                hasExplicitScope: false
            )
        }

        let remainder = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        switch prefix {
        case "@":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .documentSymbols,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        case "#":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .workspaceSymbols,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        case ":":
            let parts = remainder.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let line = parts.first.flatMap { Int($0) }
            let column = parts.count > 1 ? Int(parts[1]) : nil
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .line,
                searchText: remainder,
                line: line,
                column: column,
                hasExplicitScope: true
            )
        case ">":
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .commands,
                searchText: remainder,
                line: nil,
                column: nil,
                hasExplicitScope: true
            )
        default:
            return EditorQuickOpenQuery(
                rawText: rawQuery,
                scope: .files,
                searchText: trimmed,
                line: nil,
                column: nil,
                hasExplicitScope: false
            )
        }
    }
}
