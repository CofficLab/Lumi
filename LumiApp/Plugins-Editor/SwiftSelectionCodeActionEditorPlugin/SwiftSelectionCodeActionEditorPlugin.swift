import Foundation

@objc(LumiSwiftSelectionCodeActionEditorPlugin)
@MainActor
final class SwiftSelectionCodeActionEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.swift.selection-actions"
    let displayName: String = "Swift Selection Code Actions"
    let order: Int = 30

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
    }
}

@MainActor
final class SwiftSelectionCodeActionContributor: EditorCodeActionContributor {
    let id = "builtin.swift.selection-actions"

    func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        guard context.languageId.lowercased() == "swift" else { return [] }
        guard let selected = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selected.isEmpty else {
            return []
        }
        return [
            .init(
                id: "builtin.swift.wrap-print",
                title: "Wrap Selection with print(...)",
                command: "builtin.swift.wrap-print",
                priority: 120
            ),
            .init(
                id: "builtin.swift.wrap-debug",
                title: "Wrap Selection in #if DEBUG",
                command: "builtin.swift.wrap-debug",
                priority: 110
            )
        ]
    }
}
