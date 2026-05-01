import Foundation

enum EditorBottomPanelKind: String, CaseIterable, Equatable {
    case problems
    case references
    case searchResults
    case workspaceSymbols
    case callHierarchy

    var title: String {
        switch self {
        case .problems:
            return "Problems"
        case .references:
            return "References"
        case .searchResults:
            return "Search"
        case .workspaceSymbols:
            return "Workspace Symbols"
        case .callHierarchy:
            return "Call Hierarchy"
        }
    }

    var icon: String {
        switch self {
        case .problems:
            return "exclamationmark.bubble"
        case .references:
            return "arrow.triangle.branch"
        case .searchResults:
            return "magnifyingglass"
        case .workspaceSymbols:
            return "text.magnifyingglass"
        case .callHierarchy:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}
