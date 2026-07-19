import Foundation
import EditorService
import LumiKernel

@MainActor
public final class SwiftSelectionCodeActionContributor: SuperEditorCodeActionContributor {
    public let id = "builtin.swift.selection-actions"

    public func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        guard context.languageId.lowercased() == "swift" else { return [] }
        guard let selected = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selected.isEmpty else {
            return []
        }
        return [
            .init(
                id: "builtin.swift.wrap-print",
                title: LumiPluginLocalization.string("Wrap Selection with print(...)", bundle: .module),
                command: "builtin.swift.wrap-print",
                priority: 120
            ),
            .init(
                id: "builtin.swift.wrap-debug",
                title: LumiPluginLocalization.string("Wrap Selection in #if DEBUG", bundle: .module),
                command: "builtin.swift.wrap-debug",
                priority: 110
            )
        ]
    }
}
