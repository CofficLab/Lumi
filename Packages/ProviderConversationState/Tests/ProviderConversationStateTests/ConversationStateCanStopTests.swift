import Foundation
import ProviderAgentLoop
import Testing
@testable import ProviderConversationState

/// `canStop` 的状态矩阵。
///
/// 这组用例锁住输入区「发送 / 停止」互斥的判据：
/// **任何时候只要这个会话还有没干完的活，就必须显示停止按钮。**
///
/// `isSending` 与 `canStop` 是两件事，不要混用：
/// - `isSending` 描述「正在产出」；
/// - `canStop` 描述「还有没干完的活」——挂起（等工具授权、等 `ask_user` 回答）
///   时 AgentLoop 并不在产出，但回合确实没结束，用户必须能把它停掉。
///
/// 放在独立文件里：这个包的测试文件正被别的工作流重构，
/// 混在同一文件里容易被覆盖掉。
@Test("canStop 覆盖 running 与 suspended，不覆盖 idle 与各终态")
func canStopCoversRunningAndSuspendedButNotTerminalStates() {
    let conversationID = UUID()

    let idle = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .idle)
    let running = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .running)
    let suspended = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .suspended)
    let completed = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .completed)
    let failed = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .failed)
    let cancelled = ConversationStateSnapshot(conversationID: conversationID, agentLoopState: .cancelled)

    // 有活没干完 → 必须能停。
    #expect(running.canStop)
    #expect(suspended.canStop)

    // 已经结束（或压根没开始）→ 不该再显示停止按钮。
    #expect(!idle.canStop)
    #expect(!completed.canStop)
    #expect(!failed.canStop)
    #expect(!cancelled.canStop)

    // 挂起态是本次改动的关键：它「不在产出」但「还没干完」，
    // 所以 isSending 为假、canStop 为真。
    #expect(!suspended.isSending)
    #expect(suspended.canStop)
    #expect(running.isSending)
    #expect(running.canStop)
}
