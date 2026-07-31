import LumiKernel
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

    /// 思考内容：优先读 `reasoningContent`（流式写入 + 多数 provider 落库字段），
    /// 其次读 `metadata["thinkingContent"]`（历史兼容）。与 `MessageViewChrome`
    /// 的 `thinkingContent` 口径一致，确保流式思考过程能在正文区实时展示。
    private var thinkingContent: String? {
        if let reasoning = message.reasoningContent, !reasoning.isEmpty {
            return reasoning
        }
        if let thinking = message.metadata["thinkingContent"], !thinking.isEmpty {
            return thinking
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let thinking = thinkingContent {
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
        .padding(.horizontal, verbosity == .brief ? 0 : 12)
        .padding(.top, verbosity == .brief ? 0 : 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
