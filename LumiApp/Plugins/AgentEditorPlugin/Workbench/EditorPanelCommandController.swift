import Foundation

enum EditorPanelCommandController {
    static func apply(
        _ command: EditorPanelCommand,
        to snapshot: EditorPanelSnapshot
    ) -> EditorPanelSnapshot {
        switch command {
        case .toggleOpenEditors:
            if snapshot.isOpenEditorsPanelPresented {
                return EditorPanelSnapshot(
                    isOpenEditorsPanelPresented: false,
                    isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: true,
                isProblemsPanelPresented: false,
                isReferencePanelPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeOpenEditors:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: false,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .toggleProblems:
            if snapshot.isProblemsPanelPresented {
                return EditorPanelSnapshot(
                    isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                    isProblemsPanelPresented: false,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: false,
                isProblemsPanelPresented: true,
                isReferencePanelPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeProblems:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: false,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeReferences:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: false,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openCallHierarchy:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: true
            )

        case .closeCallHierarchy:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: false
            )
        }
    }
}
