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

    // 抑制只覆盖 seed 阶段：seed 结束必须**解除**。
    //
    // 若抑制被永久留下，UI 测试就无法在夹具会话里真的发消息——
    // 那些测试期待模型回复（如高风险工具的授权卡片）。
    // 实测：抑制永久保留时 `LumiToolApprovalSwitchUITests` 的
    // 「授权卡片未出现」两条用例全挂。
    #expect(
        agentLoop.suppressed.isEmpty,
        """
        seed 结束后仍有会话被抑制：\(agentLoop.suppressed.map { $0.uuidString.prefix(8) })
        抑制只应覆盖 seed 阶段，否则 UI 测试无法在夹具会话里正常发消息。
        """
    )
}

/// 抑制必须发生在**插入 user 消息之前**，且在 seed 结束时解除。
///
/// 若顺序颠倒，`MessageObserver` 会在 seed 期间就捕获到 user 消息并
/// 自动跑回合——此时抑制还没生效，自动回合已经启动。
///
/// 反过来，抑制也**不能**永久保留：UI 测试需要在夹具会话里真的发消息，
/// 期待模型回复。
@MainActor
@Test("夹具：抑制在插入 user 消息之前生效，且在 seed 结束后解除")
func fixtureSuppressesAutoReplyBeforeInsertingUserMessages() {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let agentLoop = RecordingAgentLoop()

    // 记录每次 insertMessage 时该会话是否已被抑制。
    var suppressionAtInsertTime: [UUID: Bool] = [:]
    var suppressedAfterSeed: Set<UUID> = []
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
    suppressedAfterSeed = agentLoop.suppressed

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

    // seed 之后必须全部解除。
    #expect(
        suppressedAfterSeed.isEmpty,
        """
        seed 结束后仍未解除抑制：\(suppressedAfterSeed.map { $0.uuidString.prefix(8) })
        """
    )
}
#endif
