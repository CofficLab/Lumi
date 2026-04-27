import Foundation

enum EditorPanelCommand: Equatable {
    case toggleProblems
    case closeProblems
    case closeReferences
    case openWorkspaceSymbolSearch
    case closeWorkspaceSymbolSearch
    case openCallHierarchy
    case closeCallHierarchy
}

struct EditorPanelSnapshot: Equatable {
    let isProblemsPanelPresented: Bool
    let isReferencePanelPresented: Bool
    let isWorkspaceSymbolSearchPresented: Bool
    let isCallHierarchyPresented: Bool
}
