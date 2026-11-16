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
        // 目标会话可能已被用户删除：点击时先校验，缺失则直接进入失败态，
        // 不切换、不发送，避免向已删除 ID 启动不可见回合（#185）。
        guard conversations.conversationExists(id: suggestion.conversationID) else {
            phase = .failed
            return
        }
        phase = .starting
        Task { @MainActor in
            let opened = await Self.performStart(
                suggestion: suggestion,
                conversations: conversations,
                sender: sender
            )
            phase = opened ? .opened : .failed
        }
    }

    /// 卡片「在新对话中开始」的可测试编排：校验目标存在 → 切换 → 发送 → 按结果收敛。
    ///
    /// 返回 `true` 表示成功打开；`false` 表示目标已删除或发送失败。失败时保留
    /// （必要时恢复）原选中态，绝不向已删除 ID 写入消息或启动回合（#185）。
    @MainActor
    static func performStart(
        suggestion: NewConversationSuggestion,
        conversations: any NewChatCapability,
        sender: any NewChatStarting
    ) async -> Bool {
        // Task 真正执行时目标仍可能被删除：切换/发送前再次校验身份。
        guard conversations.conversationExists(id: suggestion.conversationID) else {
            return false
        }
        let originalSelection = conversations.selectedConversationID
        conversations.selectConversation(id: suggestion.conversationID)
        // sendMessage 落库后由 AgentLoop 自动开始回合；此调用会等待回合结束。
        let succeeded = await sender.startIn(
            conversationID: suggestion.conversationID,
            content: suggestion.starter
        )
        guard succeeded else {
            // 发送失败：仅当选中态仍停在我们切换的目标时才恢复，避免覆盖
            // 用户在等待期间的手动切换。
            if conversations.selectedConversationID == suggestion.conversationID {
                conversations.restoreSelection(to: originalSelection)
            }
            return false
        }
        return true
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
