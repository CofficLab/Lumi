import Foundation

enum EditorPanelCommandController {
    static func apply(
        _ command: EditorPanelCommand,
        to snapshot: EditorPanelSnapshot
    ) -> EditorPanelSnapshot {
        switch command {
        case .toggleProblems:
            if snapshot.isProblemsPanelPresented {
                return EditorPanelSnapshot(
                    isProblemsPanelPresented: false,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isProblemsPanelPresented: true,
                isReferencePanelPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeProblems:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: false,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeReferences:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: false,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openCallHierarchy:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: true
            )

        case .closeCallHierarchy:
            return EditorPanelSnapshot(
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: false
            )
        }
    }
}
