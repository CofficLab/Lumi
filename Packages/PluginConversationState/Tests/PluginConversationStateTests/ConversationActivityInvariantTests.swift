import Foundation
import ProviderAgentLoop
import ProviderConversationState
import Testing
@testable import PluginConversationState

/// `activity` 的终态不变量。
///
/// # 第一性原理
///
/// `activity`（`ConversationActivity`）的语义是「这个会话**此刻**在做什么」。
/// 由此可得一条必须成立的不变量：
///
/// > **回合处于终态时，不存在「正在做的事」，`activity` 必须为 nil。**
///
/// 这条不变量必须在 **Provider 层**被强制，而不是靠每个观察者各自记得清理。
/// 靠观察者清理必然漏——它们各自只知道自己那几种事件，无法看到彼此时序。
///
/// # 真实故障
///
/// 2026-10-21 15:50:02，`edit_file` 触发授权等待，回合挂起；15:53:08 用户按下
/// 停止，回合被取消。回合死后，一条迟到的 ToolManager 事件把 activity 写回
/// `.waitingForUser`，于是聊天区底部永远显示「等待你的输入…」——而此时
/// 授权卡片早已消失，用户没有任何东西可以回答。
///
/// 详见 `AuthorizationActivityResidueTests` 对「授权路径不产生 ToolJobEvent」
/// 的取证。
@Suite("activity 的终态不变量")
struct ConversationActivityInvariantTests {

    /// 回合终结后 activity 必须消失。
    ///
    /// 这是不变量最直接的表达。
    @Test("回合进入终态后 activity 必须为空")
    @MainActor
    func terminalAgentLoopStateClearsActivity() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        // 先进入挂起等待：activity 非空是正常的。
        provider.update(
            conversationID: conversationID,
            agentLoopState: .suspended,
            activity: .waitingForUser
        )
        #expect(provider.state(for: conversationID).activity == .waitingForUser)

        // 回合终结：activity 必须消失。
        provider.update(
            conversationID: conversationID,
            agentLoopState: .cancelled,
            clearActivity: true
        )
        #expect(provider.state(for: conversationID).activity == nil)
    }

    /// 不变量的另一半：**迟到的观察者事件不得把终态回合拖回「正在做事」**。
    ///
    /// 这是真实故障的复现路径：回合取消后，ToolManager 的迟到事件带着
    /// `activity = .waitingForUser` 到达。若 Provider 不做守卫，
    /// 残留的 activity 会一直留在界面上。
    ///
    /// - Important: 这里**不**传 `clearActivity`，模拟的是「事件试图把
    ///   activity 写成 waitingForUser」这一真实情形。
    @Test("终态回合不得被迟到的事件重新标记为正在做事")
    @MainActor
    func lateEventCannotResurrectActivityOnTerminalTurn() {
        for terminal in [AgentLoopState.completed, .failed, .cancelled] {
            let provider = ConversationStateProvider()
            let conversationID = UUID()

            // 回合先进入终态。
            provider.update(
                conversationID: conversationID,
                agentLoopState: terminal,
                clearActivity: true
            )
            #expect(provider.state(for: conversationID).activity == nil)

            // 迟到的观察者事件试图把 activity 写回来。
            provider.update(
                conversationID: conversationID,
                activity: .waitingForUser
            )

            #expect(
                provider.state(for: conversationID).activity == nil,
                "\(terminal) 回合上不应残留 activity（迟到的 ToolManager 事件会触发）"
            )
        }
    }

    /// 守卫不得误伤仍在进行的回合。
    ///
    /// 如果实现方式是「只要 activity 非 nil 就拒绝写入」，那正常挂起等待
    /// 授权 / 提问也会失效——提示永远不出现，用户反而看不到任何状态。
    ///
    /// - Note: `.idle` **不在**这个列表里。回合尚未开始时不存在「正在做的事」，
    ///   此刻写入的 activity 只可能是上一回合的残留。真实链路里
    ///   `authorizationRequired` 之所以能写进去，是因为回合此前已被
    ///   `AgentLoopStateObserver.suspended` 标记为 `.suspended`。
    @Test("非终态回合的 activity 必须正常写入")
    @MainActor
    func nonTerminalTurnsStillAcceptActivity() {
        for live in [AgentLoopState.running, .suspended] {
            let provider = ConversationStateProvider()
            let conversationID = UUID()
            provider.update(
                conversationID: conversationID,
                agentLoopState: live,
                activity: .waitingForUser
            )
            #expect(
                provider.state(for: conversationID).activity == .waitingForUser,
                "\(live) 回合应当可以处于等待用户的状态"
            )
        }
    }

    /// `.idle` 回合只承载「正在发送」，其余一律拒绝。
    ///
    /// 这条比「idle 一律拒绝」更精确，原因是 `MessageSenderStateObserver` 在
    /// **消息投递阶段**就写入 `.sending`，而回合要到 `AgentLoopEvent.started`
    /// 才转成 `.running`——中间存在一个真实的 `.idle` 窗口。
    ///
    /// 把它一刀切掉会引入回归：发送提示永远不显示，或上一回合的
    /// `waitingForUser` 残留到下一次发送（回归见
    /// `LumiMessageListBriefUITests.testBottomStatusCardIsHiddenWhenIdle`）。
    @Test("idle 回合只承载正在发送")
    @MainActor
    func idleTurnOnlyAcceptsSendingActivity() {
        // `.sending` 在 idle 回合上是合法的。
        let sendingProvider = ConversationStateProvider()
        let sendingConversation = UUID()
        sendingProvider.update(
            conversationID: sendingConversation,
            agentLoopState: .idle,
            activity: .sending
        )
        #expect(sendingProvider.state(for: sendingConversation).activity == .sending)

        // 其它 activity 在 idle 回合上都是残留，必须拒绝。
        for stale in [ConversationActivity.waitingForUser, .thinking, .executingTool] {
            let provider = ConversationStateProvider()
            let conversationID = UUID()
            provider.update(
                conversationID: conversationID,
                agentLoopState: .idle,
                activity: stale
            )
            #expect(
                provider.state(for: conversationID).activity == nil,
                "idle 回合上不应残留 \(stale) —— 真实故障中这正是上一回合的 waitingForUser"
            )
        }
    }

    /// 完整快照替换同样要守住不变量。
    ///
    /// `update(_ snapshot:)` 是绕过合并逻辑的另一条入口（重启恢复、
    /// 测试夹具都可能走它），若不做同样的处理，不变量就有缺口。
    @Test("快照替换路径同样守住终态不变量")
    @MainActor
    func snapshotReplacementAlsoRespectsInvariant() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(ConversationStateSnapshot(
            conversationID: conversationID,
            agentLoopState: .cancelled,
            activity: .waitingForUser
        ))

        #expect(provider.state(for: conversationID).activity == nil)
    }
}