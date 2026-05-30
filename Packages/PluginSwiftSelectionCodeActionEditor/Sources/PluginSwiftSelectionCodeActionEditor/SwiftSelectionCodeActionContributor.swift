import Foundation
import EditorService

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
                title: String(localized: "Wrap Selection with print(...)", table: "SwiftSelectionCodeActionEditor"),
                command: "builtin.swift.wrap-print",
                priority: 120
            ),
            .init(
                id: "builtin.swift.wrap-debug",
                title: String(localized: "Wrap Selection in #if DEBUG", table: "SwiftSelectionCodeActionEditor"),
                command: "builtin.swift.wrap-debug",
                priority: 110
            )
        ]
    }
}
