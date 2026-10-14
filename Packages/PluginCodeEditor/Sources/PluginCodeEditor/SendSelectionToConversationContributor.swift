import Foundation
import ProviderEditor
import ProviderConversationInput
import ProviderConversationInputBlock

/// 将编辑器当前主选区追加到聊天输入框的右键菜单贡献者。
///
/// 该能力只负责“准备消息”，不直接调用 MessageSendingProviding，
/// 让用户仍可以在发送前补充自己的指令。
///
/// 内容通过 `ConversationInputBlockProviding` 递交：输入框超过
/// ``collapseThreshold`` 时折叠成一行 chip（与粘贴折叠一致），否则按纯文本插入，
/// 短选区仍可在发送前直接改写。
@MainActor
public final class SendSelectionToConversationContributor: EditorContextMenuProviding {
    public static let contributorID = "com.coffic.lumi.plugin.code-editor.send-selection"

    /// 选区短于此值时不折叠，保持可直接编辑的纯文本。
    ///
    /// 比粘贴的 1200 严格得多：一两个函数体就该折叠成 chip，单行改动则保留原文。
    public static let collapseThreshold = 400

    public let id = SendSelectionToConversationContributor.contributorID

    private weak var conversationInput: (any ConversationInputProviding)?
    private weak var conversationBlocks: (any ConversationInputBlockProviding)?

    public init(
        conversationInput: (any ConversationInputProviding)?,
        conversationBlocks: (any ConversationInputBlockProviding)? = nil
    ) {
        self.conversationInput = conversationInput
        self.conversationBlocks = conversationBlocks
    }

    public func provideItems(context: EditorContextMenuContext) -> [EditorContextMenuItem] {
        guard conversationInput != nil,
              let selectedText = context.selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let payload = Self.messagePayload(
            selectedText: selectedText,
            documentText: context.documentText,
            fileURL: context.fileURL,
            projectRootPath: context.projectRootPath,
            languageID: context.languageID,
            selection: context.selection
        )
        let chipTitle = Self.chipTitle(
            fileURL: context.fileURL,
            projectRootPath: context.projectRootPath,
            selection: context.selection,
            documentText: context.documentText,
            selectedText: selectedText
        )

        return [
            EditorContextMenuItem(
                id: Self.contributorID,
                title: Self.localized("Send to Conversation"),
                systemImage: "text.bubble",
                category: "chat",
                order: 10,
                priority: 10,
                dedupeKey: Self.contributorID,
                isEnabled: true,
                requiresSelection: true
            ) { [weak self] in
                self?.send(payload: payload, chipTitle: chipTitle)
            },
        ]
    }

    /// 递交选区：有块 Provider 时走折叠通道，否则退回纯文本追加。
    private func send(payload: String, chipTitle: String) {
        guard let conversationInput else { return }

        if let conversationBlocks {
            conversationBlocks.submit(
                ConversationInputBlock(
                    text: payload,
                    title: chipTitle,
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    collapseThreshold: Self.collapseThreshold
                )
            )
            conversationInput.isInputFocused = true
        } else {
            Self.append(payload, to: conversationInput)
        }
    }

    /// 读取 UTF-16 选区文本。不能直接按 Character 下标计算。
    public static func selectedText(in text: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              range.length > 0,
              let selection = Range(range, in: text) else {
            return nil
        }
        return String(text[selection])
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

    /// chip 上显示的一行来源标签，例如「Sources/Greet.swift, 行号范围 2-9」。
    public static func chipTitle(
        fileURL: URL?,
        projectRootPath: String?,
        selection: NSRange?,
        documentText: String?,
        selectedText: String
    ) -> String {
        let fileName = relativeFileName(fileURL: fileURL, projectRootPath: projectRootPath)
        let lineDescription: String
        if let selection {
            lineDescription = localizedLineDescription(
                for: selection,
                in: documentText ?? selectedText
            )
        } else {
            lineDescription = ""
        }
        return lineDescription.isEmpty ? fileName : "\(fileName), \(lineDescription)"
    }

    private static func relativeFileName(fileURL: URL?, projectRootPath: String?) -> String {
        guard let fileURL else { return localized("Current File") }

        let normalizedURL = fileURL.standardizedFileURL
        guard let projectRootPath, !projectRootPath.isEmpty else {
            return normalizedURL.lastPathComponent
        }

        let rootURL = URL(fileURLWithPath: projectRootPath).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        if normalizedURL.path.hasPrefix(rootPath) {
            return String(normalizedURL.path.dropFirst(rootPath.count))
        }
        return normalizedURL.lastPathComponent
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
