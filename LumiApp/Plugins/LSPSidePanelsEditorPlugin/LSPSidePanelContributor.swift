import Foundation
import SwiftUI

@MainActor
final class LSPSidePanelContributor: SuperEditorSidePanelContributor {
    let id: String = "builtin.lsp.side-panels"

    func provideSidePanels(state: EditorState) -> [EditorSidePanelSuggestion] {
        [
            .init(
                id: "builtin.references-panel",
                order: 10,
                isPresented: { $0.panelState.isReferencePanelPresented },
                content: { AnyView(EditorReferencesPanelView(state: $0)) }
            ),
            .init(
                id: "builtin.problems-panel",
                order: 20,
                isPresented: { $0.panelState.isProblemsPanelPresented },
                content: { AnyView(ProblemsPanelView(state: $0)) }
            )
        ]
    }
}
