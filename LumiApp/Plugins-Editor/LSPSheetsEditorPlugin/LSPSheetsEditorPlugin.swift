import Foundation
import SwiftUI

@objc(LumiLSPSheetsEditorPlugin)
@MainActor
final class LSPSheetsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.sheets"
    let displayName: String = "LSP Sheets"
    let order: Int = 17

    func register(into registry: EditorExtensionRegistry) {
        registry.registerSheetContributor(LSPSheetContributor())
    }
}

@MainActor
final class LSPSheetContributor: EditorSheetContributor {
    let id: String = "builtin.lsp.sheets"

    func provideSheets(state: EditorState) -> [EditorSheetSuggestion] {
        [
            .init(
                id: "builtin.workspace-symbol-sheet",
                order: 10,
                isPresented: { $0.isWorkspaceSymbolSearchPresented },
                onDismiss: { $0.closeWorkspaceSymbolSearch() },
                content: { state in
                    AnyView(
                        WorkspaceSymbolItemSearchView(provider: state.workspaceSymbolProvider) { symbol in
                            state.openWorkspaceSymbol(symbol)
                        }
                    )
                }
            ),
            .init(
                id: "builtin.call-hierarchy-sheet",
                order: 20,
                isPresented: { $0.isCallHierarchyPresented },
                onDismiss: { $0.closeCallHierarchy() },
                content: { state in
                    AnyView(CallHierarchySheetView(state: state))
                }
            )
        ]
    }
}
