import Foundation
import LumiKernel

/// 流式输出状态的持有者（runner 写、UI 读）。
///
/// 持有"当前正在流式的临时 assistant 行"，全程不查库。
/// 临时行用进程级稳定常量 id（`LumiStreamingRowID`），与最终落库行 id 永不冲突——
/// UI 在渲染时把它拼到 messages 末尾即可，无需任何去重逻辑。
///
/// 并发约定：本类是 `@MainActor`。runner 的 `onChunk` 在 provider 后台线程执行，
/// 通过 `await` 调用本类的写方法，运行时自动跳回主线程执行，保证对 `@Published` 的写安全。
@MainActor
public final class MessageStreamingStore: MessageStreaming {
    /// 当前正在流式的临时行（最多一条）。
    ///
    /// 非 nil 时 UI 把它拼到 messages 末尾渲染；nil 时表示无流式进行。
    /// 每次 reassign 都会触发 `objectWillChange`（经 kernel 转发，UI 自动刷新）。
    @Published public private(set) var currentStreamingRow: LumiChatMessage?

    /// 当前流式所属的会话 id。UI 据此判断是否属于当前选中的会话，避免串台。
    private(set) var streamingConversationID: UUID?

    public init(kernel: LumiKernel) {
        // 保留 kernel 引用位:未来若需查询落库状态等可复用,当前不持有(避免循环引用)。
        // 不需 weak:插件与 kernel 生命周期一致,且本类不反向持有 kernel。
    }

    public func startStreaming(conversationID: UUID) async {
        streamingConversationID = conversationID
        currentStreamingRow = LumiChatMessage(
            id: LumiStreamingRowID,
            conversationID: conversationID,
            role: .assistant,
            content: ""
        )
    }

    public func appendContent(_ piece: String) async {
        guard !piece.isEmpty, var row = currentStreamingRow else { return }
        row.content += piece
        currentStreamingRow = row
    }

    public func appendThinking(_ piece: String) async {
        guard !piece.isEmpty, var row = currentStreamingRow else { return }
        row.reasoningContent = (row.reasoningContent ?? "") + piece
        currentStreamingRow = row
    }

    public func endStreaming() async {
        currentStreamingRow = nil
        streamingConversationID = nil
    }
}
