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
@MainActor
public final class MessageStreamingStore: MessageStreaming {
    private struct StreamingState {
        var row: LumiChatMessage
        var stage: ChatStage
    }

    /// 每个会话独立保存临时行和阶段，避免并发回合互相覆盖。
    ///
    /// 刻意**不**用 `@Published`:`appendContent`/`appendThinking` 每收到一个 token
    /// 就会写一次,若标 `@Published` 会逐 token 触发 `objectWillChange` 广播。
    /// 而当前生效的 SwiftUI 消息列表(`MessageListPlugin`)是纯数据库驱动、
    /// **不**订阅本 store,唯一的订阅方(`MessageListAppKitPlugin`)处于 `.disabled`。
    /// 因此每 token 广播都是无人消费的纯开销(主线程 hop + Combine 通知)。
    /// 协议 `MessageStreaming` 要求 `ObservableObject`,去掉 `@Published` 不破坏协议,
    /// 只是停止自动广播;需要监听变化的调用方应在自己的节拍上主动读取。
    /// (未来若开启流式逐字显示,应采用「后台聚合 + 节拍推送」而非恢复 `@Published`。)
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
    }

    public func appendContent(_ piece: String, conversationID: UUID) async {
        guard !piece.isEmpty, var state = states[conversationID] else { return }
        state.row.content += piece
        state.stage = .generating
        states[conversationID] = state
    }

    public func appendThinking(_ piece: String, conversationID: UUID) async {
        guard !piece.isEmpty, var state = states[conversationID] else { return }
        state.row.reasoningContent = (state.row.reasoningContent ?? "") + piece
        state.stage = .thinking
        states[conversationID] = state
    }

    public func endStreaming(conversationID: UUID) async {
        states.removeValue(forKey: conversationID)
    }
}
