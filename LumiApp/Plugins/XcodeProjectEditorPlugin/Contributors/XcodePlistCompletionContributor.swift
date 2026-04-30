import Foundation

@MainActor
final class XcodePlistCompletionContributor: EditorCompletionContributor {
    let id = "builtin.xcode.plist-completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        let runtimeContext = XcodeProjectEditorRuntimeContext.shared
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
