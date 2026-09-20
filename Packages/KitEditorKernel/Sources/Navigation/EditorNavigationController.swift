import Foundation
import LanguageServerProtocol

public enum EditorNavigationController {
    public static func resolve(
        _ request: EditorNavigationRequest
    ) -> ResolvedEditorNavigationRequest {
        switch request {
        case let .reference(reference):
            return ResolvedEditorNavigationRequest(
                url: reference.url,
                target: EditorCursorPosition(
                    start: .init(line: reference.line, column: reference.column),
                    end: nil
                ),
                highlightLine: false
            )

        case let .workspaceSymbol(url, target),
             let .callHierarchyItem(url, target):
            return ResolvedEditorNavigationRequest(
                url: url,
                target: target,
                highlightLine: false
            )

        case let .definition(url, target, highlightLine):
            return ResolvedEditorNavigationRequest(
                url: url,
                target: target,
                highlightLine: highlightLine
            )
        }
    }

    public static func cursorPositions(for diagnostic: Diagnostic) -> [EditorCursorPosition] {
        let line = Int(diagnostic.range.start.line) + 1
        let column = Int(diagnostic.range.start.character) + 1
        let endLine = Int(diagnostic.range.end.line) + 1
        let endColumn = Int(diagnostic.range.end.character) + 1
        let hasSelection = endLine > line || endColumn > column

        return [
            EditorCursorPosition(
                start: .init(line: line, column: column),
                end: hasSelection
                    ? .init(line: endLine, column: endColumn)
                    : nil
            )
        ]
    }

    public static func resolvedDefinitionTarget(
        from target: EditorCursorPosition,
        highlightLine: Bool,
        content: String?
    ) -> EditorCursorPosition {
        guard highlightLine else { return target }

        let line = max(target.start.line, 1)
        guard let content else {
            return EditorCursorPosition(
                start: .init(line: line, column: 1),
                end: .init(line: line, column: max(target.start.column, 1))
            )
        }

        let lines = content.components(separatedBy: .newlines)
        let lineIndex = min(max(line - 1, 0), max(lines.count - 1, 0))
        let endColumn = max(lines[safe: lineIndex]?.count ?? max(target.start.column, 1), 1) + 1
        return EditorCursorPosition(
            start: .init(line: line, column: 1),
            end: .init(line: line, column: endColumn)
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
