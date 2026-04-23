import Foundation
import SwiftUI

@objc(LumiLSPSidePanelsEditorPlugin)
@MainActor
final class LSPSidePanelsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.side-panels"
    let displayName: String = "LSP Side Panels"
    let order: Int = 16

    func register(into registry: EditorExtensionRegistry) {
        registry.registerSidePanelContributor(LSPSidePanelContributor())
    }
}

@MainActor
final class LSPSidePanelContributor: EditorSidePanelContributor {
    let id: String = "builtin.lsp.side-panels"

    func provideSidePanels(state: EditorState) -> [EditorSidePanelSuggestion] {
        [
            .init(
                id: "builtin.references-panel",
                order: 10,
                isPresented: { $0.isReferencePanelPresented },
                content: { AnyView(EditorReferencesPanelView(state: $0)) }
            ),
            .init(
                id: "builtin.problems-panel",
                order: 20,
                isPresented: { $0.isProblemsPanelPresented },
                content: { AnyView(ProblemsPanelView(state: $0)) }
            )
        ]
    }
}
