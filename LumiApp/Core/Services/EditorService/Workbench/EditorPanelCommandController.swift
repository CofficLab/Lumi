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
                    isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                    isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: true,
                isOutlinePanelPresented: false,
                isProblemsPanelPresented: false,
                isReferencePanelPresented: false,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeOpenEditors:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: false,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .toggleOutline:
            if snapshot.isOutlinePanelPresented {
                return EditorPanelSnapshot(
                    isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                    isOutlinePanelPresented: false,
                    isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: false,
                isOutlinePanelPresented: true,
                isProblemsPanelPresented: false,
                isReferencePanelPresented: false,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeOutline:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: false,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .toggleProblems:
            if snapshot.isProblemsPanelPresented {
                return EditorPanelSnapshot(
                    isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                    isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                    isProblemsPanelPresented: false,
                    isReferencePanelPresented: snapshot.isReferencePanelPresented,
                    isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                    isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                    isCallHierarchyPresented: snapshot.isCallHierarchyPresented
                )
            }
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: false,
                isOutlinePanelPresented: false,
                isProblemsPanelPresented: true,
                isReferencePanelPresented: false,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeProblems:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: false,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeReferences:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: false,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .toggleWorkspaceSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: !snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeWorkspaceSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: false,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: true,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .closeWorkspaceSymbolSearch:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: false,
                isCallHierarchyPresented: snapshot.isCallHierarchyPresented
            )

        case .openCallHierarchy:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: true
            )

        case .closeCallHierarchy:
            return EditorPanelSnapshot(
                isOpenEditorsPanelPresented: snapshot.isOpenEditorsPanelPresented,
                isOutlinePanelPresented: snapshot.isOutlinePanelPresented,
                isProblemsPanelPresented: snapshot.isProblemsPanelPresented,
                isReferencePanelPresented: snapshot.isReferencePanelPresented,
                isWorkspaceSearchPresented: snapshot.isWorkspaceSearchPresented,
                isWorkspaceSymbolSearchPresented: snapshot.isWorkspaceSymbolSearchPresented,
                isCallHierarchyPresented: false
            )
        }
    }
}
