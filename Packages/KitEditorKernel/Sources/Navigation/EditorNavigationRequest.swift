import Foundation

public struct EditorCursorLocation: Equatable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct EditorCursorPosition: Equatable {
    public let start: EditorCursorLocation
    public let end: EditorCursorLocation?

    public init(start: EditorCursorLocation, end: EditorCursorLocation?) {
        self.start = start
        self.end = end
    }
}

public enum EditorNavigationRequest: Equatable {
    case reference(ReferenceResult)
    case workspaceSymbol(URL, EditorCursorPosition)
    case callHierarchyItem(URL, EditorCursorPosition)
    case definition(URL, EditorCursorPosition, highlightLine: Bool)
}

public struct ResolvedEditorNavigationRequest: Equatable {
    public let url: URL
    public let target: EditorCursorPosition
    public let highlightLine: Bool

    public init(url: URL, target: EditorCursorPosition, highlightLine: Bool) {
        self.url = url
        self.target = target
        self.highlightLine = highlightLine
    }
}
