import LumiCoreKit
import LumiUI
import MarkdownKit
import SwiftUI

struct AssistantMessageView: View {
    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            AssistantMessageBody(message: message, shouldHideAssistantBody: shouldHideAssistantBody)
        }
    }

    private var shouldHideAssistantBody: Bool {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
            return false
        }

        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return false
        }

        let lines = trimmedContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            return false
        }

        let isToolSummary = firstLine.hasPrefix("正在执行 ") || firstLine.hasPrefix("Executing ")
        return isToolSummary && lines.count <= toolCalls.count + 1
    }
}

private struct AssistantMessageBody: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let shouldHideAssistantBody: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let thinking = message.metadata["thinkingContent"], !thinking.isEmpty {
                DisclosureGroup("Thinking") {
                    Text(thinking)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }
                .font(.appCaptionEmphasized)
            }

            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shouldHideAssistantBody {
                MarkdownBlockRenderer(
                    markdown: message.content,
                    theme: ChatMarkdownTheme.make(from: theme)
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .font(.appBody)
            }

            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                ToolCallRowsView(message: message)
                    .padding(.top, shouldHideAssistantBody ? 0 : 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
