import Foundation
import EditorService
import SuperLogKit
import XcodeKit
import os

@MainActor
public final class XcodePlistCompletionContributor: SuperEditorCompletionContributor, SuperLog {
    public nonisolated static let emoji = "📋"
    nonisolated(unsafe) static var verbose: Bool = true

    public let id = "builtin.xcode.plist-completion"

    public func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        if Self.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(self.t)开始生成补全，prefix: \(context.prefix), line: \(context.line), character: \(context.character)")
            }
        }

        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else {
            if Self.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.warning("\(self.t)无法获取当前文件 URL")
                }
            }
            return []
        }

        let prefix = context.prefix
        let line = context.line
        let character = context.character
        let content = runtimeContext.currentContent ?? ""

        if Self.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(self.t)文件: \(fileURL.path), 内容长度: \(content.count)")
            }
        }

        // 将解析和匹配移到后台线程
        let rawSuggestions = await Task.detached(priority: .userInitiated) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let suggestions = PlistEditing.completionSuggestions(
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
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            if XcodePlistCompletionContributor.verbose {
                if SwiftPluginLog.verbose {
                                    SwiftPluginLog.logger.info("\(XcodePlistCompletionContributor.t)解析完成，\(suggestions.count) 条建议，耗时 \(String(format: "%.1f", elapsed))ms")
                }
            }
            return suggestions
        }.value

        if Self.verbose {
            if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(self.t)补全完成，\(rawSuggestions.count) 条建议")
            }
        }

        return rawSuggestions.map { $0.toSuggestion() }
    }
}

// MARK: - Sendable Transfer Model

private struct RawCompletionResult: Sendable {
    public let label: String
    public let insertText: String
    public let detail: String?
    public let priority: Int

    @MainActor
    public func toSuggestion() -> EditorCompletionSuggestion {
        EditorCompletionSuggestion(
            label: label,
            insertText: insertText,
            detail: detail,
            priority: priority
        )
    }
}
