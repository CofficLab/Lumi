import LumiUI
import SwiftUI

/// 「建议换个话题」卡片：展示新话题标题与任务摘要，提供一键跳转按钮。
///
/// 交互约定：点击按钮才切对话并自动发送首条消息、开始回合。切换发生在
/// 当前回合之外，因此不存在回合中途改选中态或嵌套启动回合的问题。
struct NewConversationSuggestionCard: View {
    @LumiTheme private var theme

    let suggestion: NewConversationSuggestion
    let conversations: NewChatCapability?
    let sender: NewChatStarting?

    @State private var phase: Phase = .idle

    enum Phase: Equatable {
        case idle
        case starting
        case opened
        case failed
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12, showShadow: false, borderIntensity: 0.06) {
            VStack(alignment: .leading, spacing: 10) {
                header
                Text(suggestion.starter)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                actionRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.primary)
            Text(pluginLocalization.string("Suggested New Topic"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    /// 状态区：拆成独立分支，避免单个 `switch` 表达式触发类型检查超时。
    @ViewBuilder
    private var actionRow: some View {
        switch phase {
        case .idle:
            startButton
        case .starting:
            startingIndicator
        case .opened:
            openedLabel
        case .failed:
            retryButton
        }
    }

    private var startButton: some View {
        let label = pluginLocalization.string("Start in New Conversation")
        return AppButton(
            label,
            systemImage: "arrow.up.right.square",
            style: .tonal,
            size: .small
        ) {
            start()
        }
        .help(pluginLocalization.string("Start in a new conversation"))
        .disabled(conversations == nil || sender == nil)
    }

    private var startingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text(pluginLocalization.string("Starting…"))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }

    private var openedLabel: some View {
        Label(pluginLocalization.string("Opened"), systemImage: "checkmark.circle.fill")
            .font(.appMicro)
            .foregroundColor(theme.success)
    }

    private var retryButton: some View {
        AppButton(
            pluginLocalization.string("Start in New Conversation"),
            systemImage: "arrow.clockwise",
            style: .ghost,
            size: .small
        ) {
            phase = .idle
        }
    }

    private func start() {
        guard let conversations, let sender else {
            phase = .failed
            return
        }
        phase = .starting
        Task { @MainActor in
            conversations.selectConversation(id: suggestion.conversationID)
            // sendMessage 落库后由 AgentLoop 自动开始回合；此调用会等待回合结束。
            await sender.startIn(conversationID: suggestion.conversationID, content: suggestion.starter)
            phase = .opened
        }
    }
}

// MARK: - 预览

#Preview("New Conversation Card") {
    NewConversationSuggestionCard(
        suggestion: NewConversationSuggestion(
            conversationID: UUID(),
            title: "Fix the flaky UI test",
            starter: "The UI test `testLoginButton` fails intermittently on CI. Please investigate why the button tap lands before the animation settles, and fix it."
        ),
        conversations: nil,
        sender: nil
    )
    .padding(20)
    .frame(width: 420)
}
