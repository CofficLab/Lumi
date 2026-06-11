import Foundation
import EditorService
import EditorCodeEditTextView

@MainActor
public final class EditorChatIntegrationCommandContributor: SuperEditorCommandContributor {
    public let id: String = "builtin.chat.integration"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard let textView else { return [] }
        let hasSelection = context.hasSelection

        var commands: [EditorCommandSuggestion] = []

        if hasSelection {
            commands.append(
                .init(
                    id: "builtin.add-selection-to-chat",
                    title: String(localized: "Add Selection to Chat", bundle: .module),
                    systemImage: "bubble.left.and.text.bubble.right",
                    category: EditorCommandCategory.chat.rawValue,
                    order: 1,
                    isEnabled: true
                ) {
                    Self.performAddSelectionToChat(textView: textView, state: state)
                }
            )
        }

        commands.append(
            .init(
                id: "builtin.add-location-to-chat",
                title: String(localized: "Add Location to Chat", bundle: .module),
                systemImage: "mappin.and.ellipse",
                category: EditorCommandCategory.chat.rawValue,
                order: 2,
                isEnabled: true
            ) {
                Self.performAddLocationToChat(textView: textView, state: state)
            }
        )

        return commands
    }

    // MARK: - Actions

    private static func performAddSelectionToChat(textView: TextView, state: EditorState) {
        let selections = textView.selectionManager.textSelections
        guard let firstSelection = selections.first, !firstSelection.range.isEmpty else { return }
        let fullText = textView.string as NSString
        let range = firstSelection.range
        guard range.location != NSNotFound, NSMaxRange(range) <= fullText.length else { return }
        let selectedText = fullText.substring(with: range)
        guard !selectedText.isEmpty else { return }
        let locationText = selectionLocationText(range: range, fullText: fullText, state: state)
        let languageHint = state.fileExtension

        let payload = """
        \(locationText)
        ```\(languageHint)
        \(selectedText)
        ```
        """
        EditorChatIntegrationRuntime.postAddToChat(payload, windowId: state.windowId)
    }

    private static func performAddLocationToChat(textView: TextView, state: EditorState) {
        let selection = textView.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        let fullText = textView.string as NSString
        guard selection.location != NSNotFound else { return }
        let safeSelection = NSRange(
            location: min(max(selection.location, 0), fullText.length),
            length: min(max(selection.length, 0), max(0, fullText.length - min(max(selection.location, 0), fullText.length)))
        )
        let locationText = selectionLocationText(range: safeSelection, fullText: fullText, state: state)
        EditorChatIntegrationRuntime.postAddToChat(locationText, windowId: state.windowId)
    }

    // MARK: - Helpers

    private static func selectionLocationText(range: NSRange, fullText: NSString, state: EditorState) -> String {
        let startOffset = max(0, min(range.location, fullText.length))
        let endOffset = max(startOffset, min(NSMaxRange(range), fullText.length))

        let textBeforeStart = fullText.substring(with: NSRange(location: 0, length: startOffset))
        let textBeforeEnd = fullText.substring(with: NSRange(location: 0, length: endOffset))

        let startLine = textBeforeStart.filter { $0 == "\n" }.count + 1
        let startColumn = computeColumn(in: textBeforeStart)
        let endLine = textBeforeEnd.filter { $0 == "\n" }.count + 1
        let endColumn = computeColumn(in: textBeforeEnd)
        let filePath = state.relativeFilePath

        if startLine == endLine && startColumn == endColumn {
            return "\(filePath):\(startLine):\(startColumn)"
        }
        return "\(filePath):\(startLine):\(startColumn)-\(endLine):\(endColumn)"
    }

    private static func computeColumn(in text: String) -> Int {
        if let lastNL = text.lastIndex(of: "\n") {
            return text.distance(from: text.index(after: lastNL), to: text.endIndex) + 1
        }
        return text.count + 1
    }
}

public enum EditorChatIntegrationRuntime {
    public static let addToChatNotificationName = Notification.Name("addToChat")

    public static func postAddToChat(_ text: String, windowId: UUID? = nil) {
        NotificationCenter.default.post(
            name: addToChatNotificationName,
            object: nil,
            userInfo: [
                "text": text,
                "windowId": windowId as Any,
            ]
        )
    }
}
