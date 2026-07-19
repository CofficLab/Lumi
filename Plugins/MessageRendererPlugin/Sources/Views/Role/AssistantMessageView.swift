import LumiKernel
import LumiUI
import MarkdownKit
import SwiftUI

struct AssistantMessageView: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage, showsHeader: verbosity != .brief) {
            AssistantMessageBody(message: message, shouldHideAssistantBody: message.isToolExecutionOnly)
        }
    }
}

private struct AssistantMessageBody: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
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

            if let toolCalls = message.toolCalls,
               !toolCalls.isEmpty {
                ToolCallRowsView(message: message, verbosity: verbosity)
                    .padding(.top, shouldHideAssistantBody ? 0 : 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
