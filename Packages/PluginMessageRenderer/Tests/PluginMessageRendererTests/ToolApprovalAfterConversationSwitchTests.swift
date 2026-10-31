import Foundation
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
import Testing
@testable import PluginMessageRenderer

/// 复现：**用户已处理过工具授权，切到其他对话再切回来，授权界面又出现。**
///
/// ## 症状
///
/// 用户在消息列表里点了「允许」/「拒绝」，授权卡片当场消失（消息被回写成
/// 授权终态）。但把对话切走再切回来，授权卡片**又冒出来了**。
///
/// ## 根因
///
/// 授权卡片由 `ToolApprovalRowRenderer.canRender` 决定，判据是
/// 渲染层拿到的那个 `ToolCall`：
///
/// ```
/// authorizationState == .pendingAuthorization
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 而渲染层拿到的 `ToolCall` 来自 `ToolCallRowsView.toolCalls`：
///
/// ```
/// resolvedToolCalls ?? message.toolCalls ?? []
/// ```
///
/// `resolvedToolCalls` 命中 `ToolCallResolutionCache`。而缓存的命中判据
/// **只比较 toolCall 的 id 序列**（`ToolCallResolutionCache.resolvedCalls`），
/// 完全不看 `authorizationState`：
///
/// ```
/// guard currentIDs == cachedIDs else { return nil }
/// return cached
/// ```
///
/// 于是缓存里那份「等待授权」的快照会**整体覆盖**消息里已经落库的授权终态，
/// 渲染层再次看到 `pendingAuthorization`，授权卡片重新弹出。
///
/// 切换对话会重建 `List`（`.id(selectedConversationID)`），工具行被重新物化，
/// `@State resolvedToolCalls` 清空 → 重新查缓存 → 命中那份过期快照。
/// 这正是「切走再切回才复现」的原因：留在原地时 `@State` 还持有旧值，
/// 表现相同，但切走再切回是稳定可复现的路径。
///
/// ## 这一层锁住什么
///
/// 缓存**只该缓存工具结果**，不该缓存并复活「授权状态」这种持久化事实。
/// 授权状态的唯一真相是消息；缓存命中时必须以消息为准。
///
/// 上游「授权终态有没有落库」由 `ToolAuthorizationPersistenceTests`
/// （PluginAgentLoop）与 `ToolApprovalVisibilityAfterResolutionTests`
/// （本包）覆盖；本文件负责「落库对了，但被缓存覆盖回去」这一段。
@MainActor
@Suite("授权处理后切换对话不重复弹授权")
struct ToolApprovalAfterConversationSwitchTests {

    // MARK: - 夹具

    /// 等待用户授权时的工具调用形态。
    ///
    /// 这是 `ToolExecutionManager` 命中 `requireApprovalForHighRisk` 后落库的
    /// 真实形态：占位结果 + `awaitingUserResponse = true` +
    /// `authorizationState = pendingAuthorization`。
    private func pendingToolCall(id: String) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "write_file",
            arguments: #"{"path":"/tmp/a.txt","content":"hi"}"#,
            result: MessageToolResult(
                content: #"{"toolCallId":"approval:\#(id)","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                awaitingUserResponse: true,
                interactionState: .waiting
            ),
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
        )
    }

    /// 用户已处理后消息里的工具调用形态。
    ///
    /// 对应 `MessageManager.updateToolCallResult(..., authorizationState:)`：
    /// 结果被替换，授权状态写成终态。
    private func resolvedToolCall(
        id: String,
        outcome: ToolCallAuthorizationState
    ) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "write_file",
            arguments: #"{"path":"/tmp/a.txt","content":"hi"}"#,
            result: MessageToolResult(
                content: outcome == .userApproved
                    ? "file written"
                    : "Tool execution was rejected by the user.",
                isError: outcome == .userRejected
            ),
            displayDescription: "写入 /tmp/a.txt",
            authorizationState: outcome.rawValue
        )
    }

    /// 渲染层最终拿到的工具调用。
    ///
    /// 复刻 `ToolCallRowsView` 的取数顺序：先查缓存，命中用缓存，
    /// 未命中用消息本身。
    private func renderedToolCalls(
        messageID: UUID,
        messageToolCalls: [MessageToolCall]
    ) -> [MessageToolCall] {
        ToolCallResolutionCache.shared.resolvedCalls(
            messageID: messageID,
            toolCalls: messageToolCalls
        ) ?? messageToolCalls
    }

    // MARK: - 用例

    /// 用户点了「允许」，切走再切回后授权卡片不得重新出现。
    @Test("用户已允许后切换对话再切回，授权卡片不再出现")
    func approvalCardDoesNotReappearAfterSwitchingBack() {
        let messageID = UUID()
        let toolCallID = "call-approved-switch-back"

        // 授权前：工具行首次渲染，`resolveResults` 把「全部有结果」的快照写进缓存。
        let pending = pendingToolCall(id: toolCallID)
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: messageID,
            toolCalls: [pending]
        )

        // 用户点「允许」：消息被回写成授权终态并落库。
        let approved = resolvedToolCall(id: toolCallID, outcome: .userApproved)

        // 切走再切回：List 重建 → 工具行重新物化 → 先查缓存。
        let rendered = renderedToolCalls(messageID: messageID, messageToolCalls: [approved])

        #expect(
            rendered.first?.authorizationState == ToolCallAuthorizationState.userApproved.rawValue,
            "缓存复活了过期的授权状态，消息里已落库的 userApproved 被覆盖回 pendingAuthorization"
        )
        #expect(
            !ToolApprovalRowRenderer().canRender(toolCall: rendered[0].agentToolCall),
            "切回对话后授权卡片重新出现，尽管用户已经允许过"
        )
    }

    /// 用户点了「拒绝」，切走再切回后同样不得重新出现。
    ///
    /// 拒绝没有工具实际执行，结果与授权状态同时被替换——但渲染判据只看
    /// `authorizationState`，因此与「允许」走同一条路径。
    @Test("用户已拒绝后切换对话再切回，授权卡片不再出现")
    func approvalCardDoesNotReappearAfterRejecting() {
        let messageID = UUID()
        let toolCallID = "call-rejected-switch-back"

        let pending = pendingToolCall(id: toolCallID)
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: messageID,
            toolCalls: [pending]
        )

        let rejected = resolvedToolCall(id: toolCallID, outcome: .userRejected)

        let rendered = renderedToolCalls(messageID: messageID, messageToolCalls: [rejected])

        #expect(
            rendered.first?.authorizationState == ToolCallAuthorizationState.userRejected.rawValue,
            "缓存复活了过期的授权状态，消息里已落库的 userRejected 被覆盖回 pendingAuthorization"
        )
        #expect(
            !ToolApprovalRowRenderer().canRender(toolCall: rendered[0].agentToolCall),
            "切回对话后授权卡片重新出现，尽管用户已经拒绝过"
        )
    }

    /// 缓存命中不得把「等待授权」的占位结果一并复活。
    ///
    /// 占位结果带 `awaitingUserResponse = true`，它和 `authorizationState`
    /// 一起构成渲染判据的两个条件。授权终态落库后占位结果已被替换，
    /// 缓存若把它带回来，用户看到的就是一张「已提交：等待继续执行…」
    /// 却早已失效的授权卡片。
    @Test("缓存命中不得复活等待授权的占位结果")
    func cacheDoesNotResurrectAwaitingUserResponseResult() {
        let messageID = UUID()
        let toolCallID = "call-placeholder-not-resurrected"

        let pending = pendingToolCall(id: toolCallID)
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: messageID,
            toolCalls: [pending]
        )

        let approved = resolvedToolCall(id: toolCallID, outcome: .userApproved)
        let rendered = renderedToolCalls(messageID: messageID, messageToolCalls: [approved])

        #expect(
            rendered.first?.result?.awaitingUserResponse == false,
            "缓存把等待授权的占位结果带了回来，授权卡片会以假复活的形式出现"
        )
        #expect(
            rendered.first?.result?.content == "file written",
            "缓存把过期的工具结果带了回来，消息里已落库的真实结果被覆盖"
        )
    }

    /// 缓存命中时，消息缺失的结果仍应由缓存补齐。
    ///
    /// 缓存的**本意**是省掉「消息里没有结果时逐个 await 查询工具结果」
    /// 的开销（见 `ToolCallRowsView.resolveResults` 的注释）。修复「复活过期
    /// 授权状态」不能把这个本意一起废掉：消息里 `result == nil` 的调用，
    /// 仍应拿到缓存里查好的结果。
    @Test("缓存仍可补齐消息里缺失的工具结果")
    func cacheStillFillsMissingResults() {
        let messageID = UUID()
        let toolCallID = "call-result-filled-from-cache"

        // 首次渲染：消息里还没有结果，由 capability 查出结果后写入缓存。
        let resolved = MessageToolCall(
            id: toolCallID,
            name: "read_file",
            arguments: "{}",
            result: MessageToolResult(content: "file contents"),
            authorizationState: ToolCallAuthorizationState.noRisk.rawValue
        )
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: messageID,
            toolCalls: [resolved]
        )

        // 重新物化：消息里的调用还没有结果（尚未落库），缓存负责补齐。
        let withoutResult = MessageToolCall(
            id: toolCallID,
            name: "read_file",
            arguments: "{}",
            result: nil,
            authorizationState: ToolCallAuthorizationState.noRisk.rawValue
        )
        let rendered = renderedToolCalls(messageID: messageID, messageToolCalls: [withoutResult])

        #expect(
            rendered.first?.result?.content == "file contents",
            "缓存命中时不再补齐缺失结果，工具行会退化成 loading 行"
        )
    }

    /// 尚未处理的授权，缓存命中后**仍然要**显示授权卡片。
    ///
    /// 这是上一条的镜像：修复不得把「授权卡片该出现时却不出现」也带进来。
    @Test("未处理的授权仍然显示授权卡片")
    func pendingApprovalStillRendersCard() {
        let messageID = UUID()
        let toolCallID = "call-still-pending"

        let pending = pendingToolCall(id: toolCallID)
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: messageID,
            toolCalls: [pending]
        )

        let rendered = renderedToolCalls(messageID: messageID, messageToolCalls: [pending])

        #expect(
            ToolApprovalRowRenderer().canRender(toolCall: rendered[0].agentToolCall),
            "授权尚未处理时授权卡片必须出现"
        )
    }
}
