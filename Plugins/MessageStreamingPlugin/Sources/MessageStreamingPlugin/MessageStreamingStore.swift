import Foundation
import LumiKernel

/// 流式输出状态的持有者（runner 写、UI 读）。
///
/// 按会话持有正在流式的临时 assistant 行，全程不查库。
/// 临时行用进程级稳定常量 id（`LumiStreamingRowID`），与最终落库行 id 永不冲突——
/// UI 在渲染时把它拼到 messages 末尾即可，无需任何去重逻辑。
///
/// 并发约定：本类是 `@MainActor`。runner 的 `onChunk` 在 provider 后台线程执行，
/// 通过 `await` 调用本类的写方法，运行时自动跳回主线程执行，保证对 `states` 的写安全。
/// 写方法末尾手动 `objectWillChange.send()` 通知订阅方;订阅方(SwiftUI 消息列表
/// ViewModel)用帧门禁把逐 token 广播合并成每帧最多一次 UI 刷新。
@MainActor
public final class MessageStreamingStore: MessageStreaming {
    private struct StreamingState {
        var row: LumiChatMessage
        var stage: ChatStage
    }

    /// 每个会话独立保存临时行和阶段，避免并发回合互相覆盖。
    ///
    /// 刻意**不**用 `@Published`:那会让每个 token 都在 `willSet` 自动广播。
    /// 改为在写方法末尾手动 `objectWillChange.send()`——语义等价,但让我们能
    /// 精确控制广播时机,并便于将来在写方法里做聚合优化而不影响广播契约。
    /// 订阅方(SwiftUI 消息列表 ViewModel)用自己的帧门禁把逐 token 广播合并成
    /// 每帧(~16ms)最多一次 UI 刷新,因此逐 token 广播的成本是可接受的。
    private var states: [UUID: StreamingState] = [:]

    public init(kernel: LumiKernel) {
        // 保留 kernel 引用位:未来若需查询落库状态等可复用,当前不持有(避免循环引用)。
        // 不需 weak:插件与 kernel 生命周期一致,且本类不反向持有 kernel。
    }

    public func streamingRow(for conversationID: UUID) -> LumiChatMessage? {
        states[conversationID]?.row
    }

    public func streamingStage(for conversationID: UUID) -> ChatStage {
        states[conversationID]?.stage ?? .idle
    }

    public func startStreaming(conversationID: UUID) async {
        states[conversationID] = StreamingState(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: ""
            ),
            stage: .sending
        )
        objectWillChange.send()
    }

    public func appendContent(_ piece: String, conversationID: UUID) async {
        guard !piece.isEmpty, var state = states[conversationID] else { return }
        state.row.content += piece
        state.stage = .generating
        states[conversationID] = state
        objectWillChange.send()
    }

    public func appendThinking(_ piece: String, conversationID: UUID) async {
        guard !piece.isEmpty, var state = states[conversationID] else { return }
        state.row.reasoningContent = (state.row.reasoningContent ?? "") + piece
        state.stage = .thinking
        states[conversationID] = state
        objectWillChange.send()
    }

    public func endStreaming(conversationID: UUID) async {
        states.removeValue(forKey: conversationID)
        objectWillChange.send()
    }
}
