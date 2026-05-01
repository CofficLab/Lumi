import Foundation
import CodeEditSourceEditor

enum EditorNavigationRequest: Equatable {
    case reference(ReferenceResult)
    case workspaceSymbol(URL, CursorPosition)
    case callHierarchyItem(URL, CursorPosition)
    case definition(URL, CursorPosition, highlightLine: Bool)
}

struct ResolvedEditorNavigationRequest: Equatable {
    let url: URL
    let target: CursorPosition
    let highlightLine: Bool
}
