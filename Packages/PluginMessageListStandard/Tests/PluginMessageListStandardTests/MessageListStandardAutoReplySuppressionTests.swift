#if DEBUG
import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

/// 记录「自动回复抑制」状态的 AgentLoop 替身。
///
/// 只实现协议里与本用例相关的那几个成员：夹具只需要调用
/// `setAutoReplySuppressed(_:for:)`，用例再回头断言每个会话都被抑制了。
@MainActor
private final class RecordingAgentLoop: AgentLoopProviding {
    private(set) var suppressed: Set<UUID> = []

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {
        if suppressed {
            self.suppressed.insert(conversationID)
        } else {
            self.suppressed.remove(conversationID)
        }
    }

    func isAutoReplySuppressed(for conversationID: UUID) -> Bool {
        suppressed.contains(conversationID)
    }

    // MARK: - 其余成员：本用例用不到，走协议默认实现

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .cancelled }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .cancelled }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

/// 夹具必须抑制「自动回复」——这是会话列表顺序稳定的**前提**。
///
/// ## 缺陷现象
///
/// UI 测试里会话列表的顺序在 run-to-run 之间摇摆：同一夹具连续两次运行，
/// 侧栏里会话的上下次序不同。按标题定位会话因此偶发失败，
/// 失败点却落在「会话在列表里不可见」这种指错方向的断言上。
///
/// ## 根因
///
/// 夹具插入 **user 消息**；`PluginAgentLoop.MessageObserver` 监听
/// `addMessageInsertedObserver`，对 `role == .user` 的消息**自动 `runTurn`**。
/// 自动回合会写回一条 `createdAt = now` 的助手消息，把该会话的
/// `lastMessageAt` 推到「现在」。
///
/// 关键在于：**几个会话的自动回合完成时刻各不相同**（微秒级差异），
/// 而会话列表按 `lastMessageAt` 倒序排列 —— 于是列表顺序由这场竞态决定，
/// 而不是由数据决定。
///
/// 实测（V2 夹具，4 个会话）：修复前两次运行分别得到
/// `Huge → Large → Tool Group → Small` 与 `Tool Group → Huge → Large → Small`。
///
/// ## 修法
///
/// 夹具在 seed 之前对每个会话调用 `setAutoReplySuppressed(true, for:)`，
/// 阻断自动回合。范式与 `PluginAgentLoop.ErrorRetryUITestingSupport` 一致
/// —— 它同样因为插入 user 消息而必须显式抑制自动回复。
///
/// 这条用例把「每个会话都被抑制」钉死：将来有人删掉抑制调用，
/// 会话列表顺序会重新开始摇摆，而单看 UI 断言很难立刻归因到此处。
@MainActor
@Test("夹具：每个会话都抑制自动回复，否则会话列表顺序会摇摆")
func fixtureSuppressesAutoReplyForEveryConversation() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let agentLoop = RecordingAgentLoop()

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages,
        agentLoop: agentLoop
    )

    let titles = conversations.conversations.compactMap(\.title)
    #expect(!titles.isEmpty, "夹具未种出任何会话")

    // 每个会话都必须被抑制。
    for conversation in conversations.conversations {
        #expect(
            agentLoop.isAutoReplySuppressed(for: conversation.id),
            """
            会话「\(conversation.title ?? "nil")」未抑制自动回复。
            未抑制时 `PluginAgentLoop.MessageObserver` 会为该会话自动跑一个回合，
            写回 `createdAt = now` 的助手消息，把 `lastMessageAt` 推到「现在」——
            几个会话的自动回合完成时刻不同，会话列表顺序因此在 run-to-run 之间摇摆。
            """
        )
    }

    // 被抑制的会话数必须与种出的会话数一致（不多不少）。
    #expect(
        agentLoop.suppressed.count == conversations.conversations.count,
        """
        抑制的会话数应与种出的会话数一致，实际 \
        抑制=\(agentLoop.suppressed.count) 会话=\(conversations.conversations.count)
        """
    )
}

/// 抑制必须发生在**插入 user 消息之前**。
///
/// 若顺序颠倒，`MessageObserver` 会在 seed 期间就捕获到 user 消息并
/// 自动跑回合——此时抑制还没生效，自动回合已经启动。
///
/// 因此这里断言的是「seed 完成后会话已被抑制」，而不是「过程中被抑制过」：
/// 前者能抓住「抑制代码被删掉」，后者不能。
@MainActor
@Test("夹具：抑制在插入 user 消息之前生效，不会漏掉自动回合")
func fixtureSuppressesAutoReplyBeforeInsertingUserMessages() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let agentLoop = RecordingAgentLoop()

    // 记录每次 insertMessage 时该会话是否已被抑制。
    var suppressionAtInsertTime: [UUID: Bool] = [:]
    let observer = messages.addMessageInsertedObserver { message, conversationID in
        guard message.role == .user else { return }
        suppressionAtInsertTime[conversationID] = agentLoop.isAutoReplySuppressed(for: conversationID)
    }
    defer { observer.cancel() }

    MessageListStandardUITestingSupport.seed(
        conversations: conversations,
        messages: messages,
        agentLoop: agentLoop
    )

    #expect(
        !suppressionAtInsertTime.isEmpty,
        "夹具没有插入任何 user 消息，用例前提不成立"
    )
    for (conversationID, wasSuppressed) in suppressionAtInsertTime {
        #expect(
            wasSuppressed,
            """
            会话 \(conversationID.uuidString.prefix(8)) 在插入 user 消息时尚未抑制自动回复。
            抑制必须先于插入，否则 `MessageObserver` 会当场启动自动回合。
            """
        )
    }
}
#endif
