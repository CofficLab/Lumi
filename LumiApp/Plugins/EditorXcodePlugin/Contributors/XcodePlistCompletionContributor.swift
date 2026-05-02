import Foundation

@MainActor
final class XcodePlistCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.xcode.plist-completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else { return [] }
        return PlistEditing.completionSuggestions(
            prefix: context.prefix,
            line: context.line,
            character: context.character,
            content: runtimeContext.currentContent,
            fileURL: fileURL
        )
    }
}
