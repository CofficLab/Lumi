import Foundation
import XcodeKit
import os

@MainActor
final class XcodePlistCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.xcode.plist-completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else { return [] }

        let prefix = context.prefix
        let line = context.line
        let character = context.character
        let content = runtimeContext.currentContent ?? ""

        // 将解析和匹配移到后台线程
        let rawSuggestions = await Task.detached(priority: .userInitiated) {
            return PlistEditing.completionSuggestions(
                prefix: prefix,
                line: line,
                character: character,
                content: content,
                fileURL: fileURL
            ).map { suggestion in
                RawCompletionResult(
                    label: suggestion.label,
                    insertText: suggestion.insertText,
                    detail: suggestion.detail,
                    priority: suggestion.priority
                )
            }
        }.value

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("📋 XcodePlistCompletionContributor | 补全完成，\(rawSuggestions.count) 条建议")
        }

        return rawSuggestions.map { $0.toSuggestion() }
    }
}

// MARK: - Sendable Transfer Model

private struct RawCompletionResult: Sendable {
    let label: String
    let insertText: String
    let detail: String?
    let priority: Int

    @MainActor
    func toSuggestion() -> EditorCompletionSuggestion {
        EditorCompletionSuggestion(
            label: label,
            insertText: insertText,
            detail: detail,
            priority: priority
        )
    }
}
