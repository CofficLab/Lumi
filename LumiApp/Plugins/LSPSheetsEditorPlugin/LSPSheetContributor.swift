import Foundation
import SwiftUI

@MainActor
final class LSPSheetContributor: EditorSheetContributor {
    let id: String = "builtin.lsp.sheets"

    func provideSheets(state: EditorState) -> [EditorSheetSuggestion] {
        [
            .init(
                id: "builtin.workspace-symbol-sheet",
                order: 10,
                isPresented: { $0.panelState.isWorkspaceSymbolSearchPresented },
                onDismiss: { $0.performPanelCommand(.closeWorkspaceSymbolSearch) },
                content: { state in
                    AnyView(
                        Group {
                            if let provider = state.workspaceSymbolProvider as? WorkspaceSymbolProvider {
                                WorkspaceSymbolItemSearchView(provider: provider) { symbol in
                                    state.performOpenItem(.workspaceSymbol(symbol))
                                }
                            }
                        }
                    )
                }
            ),
            .init(
                id: "builtin.call-hierarchy-sheet",
                order: 20,
                isPresented: { $0.panelState.isCallHierarchyPresented },
                onDismiss: { $0.performPanelCommand(.closeCallHierarchy) },
                content: { state in
                    AnyView(CallHierarchySheetView(state: state))
                }
            )
        ]
    }
}
