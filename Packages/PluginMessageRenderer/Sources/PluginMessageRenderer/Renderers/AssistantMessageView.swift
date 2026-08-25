import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import SwiftUI

struct AssistantMessageView: View {
    let kernel: KernelCoreContainer
    let message: Message
    let verbosity: LumiResponseVerbosity

    var body: some View {
        MessageViewChrome(message: message, showsHeader: verbosity != .brief, verbosity: verbosity) {
            AssistantMessageBody(kernel: kernel, message: message, shouldHideAssistantBody: message.isToolExecutionOnly, verbosity: verbosity)
        }
    }
}

private struct AssistantMessageBody: View {
    @LumiTheme private var theme
    @State private var isReasoningExpanded = false

    let kernel: KernelCoreContainer
    let message: Message
    let shouldHideAssistantBody: Bool
    let verbosity: LumiResponseVerbosity

    private var reasoningContent: String? {
        guard let reasoning = message.reasoningContent,
              !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return reasoning
    }

    /// 内容是否含可见字符。
    ///
    /// 不用 `trimmingCharacters(in:).isEmpty` —— 那会为每次 body 求值
    /// 全串扫描并构造新字符串;`contains` 在首个非空白字符处即返回,
    /// 正常内容下平均 O(1)(行在滚动/流式刷新中会被高频求值)。
    private var hasVisibleContent: Bool {
        message.content.contains { !$0.isWhitespace && !$0.isNewline }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let reasoningContent, self.verbosity == .detailed {
                reasoningBlock(reasoningContent)
            }

            if hasVisibleContent && !shouldHideAssistantBody {
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

    @ViewBuilder
    private func reasoningBlock(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                isReasoningExpanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(theme.textSecondary)
                        .rotationEffect(.degrees(isReasoningExpanded ? 90 : 0))
                    Text(LumiPluginLocalization.string("思考过程", bundle: .module))
                        .font(.appCaptionEmphasized)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isReasoningExpanded {
                MarkdownBlockRenderer(
                    markdown: reasoning,
                    theme: ChatMarkdownTheme.make(from: theme)
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.elevatedSurface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.2), value: isReasoningExpanded)
    }
}
