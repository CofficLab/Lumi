import LumiKernel
import LumiKernel
import LumiUI
import MarkdownKit
import SwiftUI

struct AssistantMessageView: View {
    let kernel: LumiKernel
    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    var body: some View {
        MessageViewChrome(message: message, showsHeader: verbosity != .brief, verbosity: verbosity) {
            AssistantMessageBody(kernel: kernel, message: message, shouldHideAssistantBody: message.isToolExecutionOnly, verbosity: verbosity)
        }
    }
}

private struct AssistantMessageBody: View {
    @LumiTheme private var theme

    let kernel: LumiKernel
    let message: LumiChatMessage
    let shouldHideAssistantBody: Bool
    let verbosity: LumiResponseVerbosity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                ToolCallRowsView(kernel: kernel, message: message, verbosity: verbosity)
                    .padding(.top, shouldHideAssistantBody ? 0 : 4)
            }
        }
        .padding(.horizontal, verbosity == .brief ? 0 : 12)
        .padding(.top, verbosity == .brief ? 0 : 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
