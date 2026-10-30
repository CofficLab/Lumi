#if DEBUG
import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// 失败回合「重试」按钮的 UI 测试夹具（仅 DEBUG）。
///
/// 当 App 以 `--lumi-ui-testing-error-retry` 启动时，本夹具在 Chat 会话里造出
/// 一个确定性的失败状态：一条 role=error 消息 + AgentLoop 中真实的 `.failed`
/// 回合（走 `TurnReducer`，与真实 LLM 失败路径一致）。
///
/// ## UI 测试如何判定「重试真的生效」
///
/// 夹具监听 AgentLoop 的 `.started` 事件，一旦收到就插入一条带固定正文的
/// 标记消息（`retryMarkerContent`）。UI 测试断言这条消息出现即可确认
/// 重试按钮点击后**确实重跑了一个新回合**。
///
/// 不采用「按钮消失」或「错误行增加」作为判据：重跑之后回合可能成功、
/// 再次失败、或被别的插件改写界面，界面层面的结果并不唯一；
/// 而「新回合确实启动了」这件事是确定的。
///
/// 范式参照 MiniMax 的 `--lumi-ui-testing` 桩网络注入（见 `MiniMaxUITestingSupport`）。
///
/// - Note: 夹具只写入初始状态并旁听回合事件，不替换任何 Provider 行为；
///   点击重试走的是生产路径（`RetryTurnButton` → capability →
///   `AgentLoopManager.retryTurn`）。
@MainActor
public enum ErrorRetryUITestingSupport {
    /// 启用本夹具的启动参数。
    public static let launchArgument = "--lumi-ui-testing-error-retry"

    /// 错误消息正文，UI 测试据此断言 error 行已渲染。
    public static let errorContent = "UI Testing Request Failed"

    /// 新回合启动时插入的标记消息正文。
    ///
    /// UI 测试等待它出现，以此确认重试按钮点击后真实重跑了一个回合。
    public static let retryMarkerContent = "UI Testing Retry Accepted"

    /// 夹具会话标题，便于在 UI 上人工确认夹具已生效。
    public static let conversationTitle = "Error Retry UI Testing"

    /// 夹具强制使用的详细度。
    ///
    /// header 的操作按钮组只在 `.detailed` 级别始终显示，其他级别需要鼠标悬停
    /// 150ms 才物化（见 `MessageViewChrome.showsActions`）。悬停不可靠地驱动，
    /// 因此夹具直接把会话设成 `.detailed`，让按钮稳定可见。
    public static let verbosity: ResponseVerbosity = .detailed

    /// 固定回合 ID：稳定值便于 UI 测试与日志对照。
    public static let failedTurnID = UUID(uuidString: "0000E170-0000-4000-8000-000000000017")!

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 在 `AgentLoopManager` 上植入一个失败回合，并写入配套消息。
    static func seedFailedTurn(
        in manager: AgentLoopManager,
        conversationID: UUID,
        messages: any MessageManaging
    ) {
        let started = TurnReducer.reduce(TurnRuntime(), event: .startTurn(turnID: failedTurnID))
        let failed = TurnReducer.reduce(started.0, event: .llmFailed(reason: errorContent))
        manager.runtimes[conversationID] = failed.0

        // 必须抑制自动回复：下面插入的 user 消息会被 `MessageObserver` 捕获并
        // 自动 `runTurn`，新回合会把刚植入的失败运行时整个覆盖掉
        // （lastTurnID 变成新回合 ID），导致 `canRetryTurn` 恒为 false。
        manager.setAutoReplySuppressed(true, for: conversationID)

        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "UI testing prompt",
                turnID: failedTurnID
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .error,
                content: errorContent,
                turnID: failedTurnID,
                isError: true,
                rawErrorDetail: errorContent
            ),
            to: conversationID
        )
    }

    /// 旁听回合启动事件，为 UI 测试插入可观测的标记消息。
    ///
    /// - Note: 标记用 `.system` 而非 `.status`：消息列表在流式行可见时会
    ///   丢弃历史里的 `.status` 行（见 `MessageListRowBuilder.buildHistory`），
    ///   而重试恰好会进入流式，`.status` 标记因此根本不会显示。
    ///   `.system` 行始终保留。
    ///
    /// - Returns: 需要在插件卸载时 `cancel()` 的句柄。
    static func observeTurnStarts(
        manager: AgentLoopManager,
        messages: any MessageManaging,
        conversationID: UUID
    ) -> any AgentLoopObserverHandle {
        var markerInserted = false
        return manager.addAgentLoopObserver { event in
            guard case .started(let startedConversationID, _) = event,
                  startedConversationID == conversationID,
                  !markerInserted else { return }
            // 只标记第一次：夹具自己的 seed 不发 started，重试发一次。
            markerInserted = true
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .system,
                    content: retryMarkerContent
                ),
                to: conversationID
            )
        }
    }
}
#endif