import EditorService
import Foundation
import ProviderConversationInput

/// 将编辑器当前主选区追加到聊天输入框的右键菜单贡献者。
///
/// 该能力只负责“准备消息”，不直接调用 MessageSendingProviding，
/// 让用户仍可以在发送前补充自己的指令。
@MainActor
public final class SendSelectionToConversationContributor: SuperEditorContextMenuContributor {
    public static let contributorID = "com.coffic.lumi.plugin.code-editor.send-selection"

    public let id = SendSelectionToConversationContributor.contributorID

    private weak var conversationInput: (any ConversationInputProviding)?

    public init(conversationInput: (any ConversationInputProviding)?) {
        self.conversationInput = conversationInput
    }

    public func provideContextMenuItems(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorContextMenuItemSuggestion] {
        guard conversationInput != nil,
              context.hasSelection,
              let textView,
              let selectedText = Self.selectedText(in: textView),
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let payload = Self.messagePayload(
            selectedText: selectedText,
            documentText: textView.string,
            fileURL: state.currentFileURL,
            projectRootPath: state.projectRootPath,
            languageID: context.languageId,
            selection: textView.selectionManager.textSelections.first?.range
        )

        return [
            EditorContextMenuItemSuggestion(
                id: Self.contributorID,
                title: Self.localized("Send to Conversation"),
                systemImage: "text.bubble",
                category: EditorCommandCategory.chat.rawValue,
                order: 10,
                isEnabled: true,
                metadata: EditorContributionMetadata(
                    priority: 10,
                    dedupeKey: Self.contributorID,
                    whenClause: .key(.hasSelection)
                )
            ) { [weak self] in
                guard let self, let conversationInput = self.conversationInput else { return }
                Self.append(payload, to: conversationInput)
            },
        ]
    }

    /// 读取主选区文本。TextView 的选区使用 UTF-16 NSRange，必须通过 String
    /// 的 Range 转换，不能直接按 Character 下标计算。
    public static func selectedText(in textView: TextView) -> String? {
        guard let selection = textView.selectionManager.textSelections.first?.range,
              selection.location != NSNotFound,
              selection.length > 0,
              let range = Range(selection, in: textView.string) else {
            return nil
        }
        return String(textView.string[range])
    }

    /// 生成带文件和语言上下文的 Markdown 消息。
    public static func messagePayload(
        selectedText: String,
        documentText: String? = nil,
        fileURL: URL?,
        projectRootPath: String?,
        languageID: String,
        selection: NSRange?
    ) -> String {
        let fileName: String
        if let fileURL {
            let normalizedURL = fileURL.standardizedFileURL
            if let projectRootPath, !projectRootPath.isEmpty {
                let rootURL = URL(fileURLWithPath: projectRootPath).standardizedFileURL
                let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
                if normalizedURL.path.hasPrefix(rootPath) {
                    fileName = String(normalizedURL.path.dropFirst(rootPath.count))
                } else {
                    fileName = normalizedURL.lastPathComponent
                }
            } else {
                fileName = normalizedURL.lastPathComponent
            }
        } else {
            fileName = localized("Current File")
        }

        let lineDescription: String
        if let selection {
            lineDescription = localizedLineDescription(
                for: selection,
                in: documentText ?? selectedText
            )
        } else {
            lineDescription = ""
        }

        let location = lineDescription.isEmpty ? fileName : "\(fileName), \(lineDescription)"
        let fence = markdownFence(for: selectedText)
        let heading = localized("Selected code")
        return "\(heading) (\(location)):\n\n\(fence)\(languageID)\n\(selectedText)\n\(fence)"
    }

    public static func append(_ payload: String, to input: any ConversationInputProviding) {
        let existing = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        input.text = existing.isEmpty ? payload : "\(existing)\n\n\(payload)"
        input.isInputFocused = true
    }

    private static func localized(_ key: String) -> String {
        CodeEditorLocalization.string(key)
    }

    private static func localizedLineDescription(for selection: NSRange, in documentText: String) -> String {
        let textLength = documentText.utf16.count
        let startOffset = min(max(selection.location, 0), textLength)
        let endOffset = min(max(selection.location + max(selection.length - 1, 0), 0), textLength)
        let startLine = documentText.utf16.prefix(startOffset).reduce(into: 1) { line, codeUnit in
            if codeUnit == 10 { line += 1 }
        }
        let endLine = documentText.utf16.prefix(endOffset).reduce(into: 1) { line, codeUnit in
            if codeUnit == 10 { line += 1 }
        }
        let lineRange = startLine == endLine ? "\(startLine)" : "\(startLine)-\(endLine)"
        let lineRangeLabel = localized("Line range")
        return "\(lineRangeLabel) \(lineRange)"
    }

    private static func markdownFence(for text: String) -> String {
        let longestBacktickRun = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                var longest = 0
                var current = 0
                for character in line {
                    if character == "`" {
                        current += 1
                        longest = max(longest, current)
                    } else {
                        current = 0
                    }
                }
                return longest
            }
            .max() ?? 0
        return String(repeating: "`", count: max(3, longestBacktickRun + 1))
    }
}
