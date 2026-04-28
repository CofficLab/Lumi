import Foundation

enum EditorPanelCommand: Equatable {
    case toggleOpenEditors
    case closeOpenEditors
    case toggleProblems
    case closeProblems
    case closeReferences
    case openWorkspaceSymbolSearch
    case closeWorkspaceSymbolSearch
    case openCallHierarchy
    case closeCallHierarchy
}

struct EditorPanelSnapshot: Equatable {
    let isOpenEditorsPanelPresented: Bool
    let isProblemsPanelPresented: Bool
    let isReferencePanelPresented: Bool
    let isWorkspaceSymbolSearchPresented: Bool
    let isCallHierarchyPresented: Bool
}
