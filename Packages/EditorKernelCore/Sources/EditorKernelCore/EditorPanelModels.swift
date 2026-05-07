import Foundation

public enum EditorBottomPanelKind: String, CaseIterable, Equatable {
    case problems
    case references
    case searchResults
    case workspaceSymbols
    case callHierarchy

    public var title: String {
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

    public var icon: String {
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

public enum EditorPanelCommand: Equatable {
    case toggleOpenEditors
    case closeOpenEditors
    case toggleOutline
    case closeOutline
    case toggleProblems
    case closeProblems
    case closeReferences
    case toggleWorkspaceSearch
    case closeWorkspaceSearch
    case openWorkspaceSymbolSearch
    case closeWorkspaceSymbolSearch
    case openCallHierarchy
    case closeCallHierarchy
}

public struct EditorPanelSnapshot: Equatable {
    public let isOpenEditorsPanelPresented: Bool
    public let isOutlinePanelPresented: Bool
    public let isProblemsPanelPresented: Bool
    public let isReferencePanelPresented: Bool
    public let isWorkspaceSearchPresented: Bool
    public let isWorkspaceSymbolSearchPresented: Bool
    public let isCallHierarchyPresented: Bool

    public init(
        isOpenEditorsPanelPresented: Bool,
        isOutlinePanelPresented: Bool,
        isProblemsPanelPresented: Bool,
        isReferencePanelPresented: Bool,
        isWorkspaceSearchPresented: Bool,
        isWorkspaceSymbolSearchPresented: Bool,
        isCallHierarchyPresented: Bool
    ) {
        self.isOpenEditorsPanelPresented = isOpenEditorsPanelPresented
        self.isOutlinePanelPresented = isOutlinePanelPresented
        self.isProblemsPanelPresented = isProblemsPanelPresented
        self.isReferencePanelPresented = isReferencePanelPresented
        self.isWorkspaceSearchPresented = isWorkspaceSearchPresented
        self.isWorkspaceSymbolSearchPresented = isWorkspaceSymbolSearchPresented
        self.isCallHierarchyPresented = isCallHierarchyPresented
    }
}
