import Combine
import Foundation

/// 流式输出能力协议（runner 写、UI 读）。
///
/// 持有"当前正在流式的临时 assistant 行"，全程不查库。
/// 临时行用进程级**稳定常量 id**（`streamingRowID`），与最终落库行 id 永不冲突，
/// UI 在渲染时把它拼到 `messages` 末尾即可，无需任何去重逻辑——
/// 流式与持久化两种语义因此彻底隔离。
///
/// 调用约定：所有写方法标 `async`。runner 的 `onChunk` 在 provider 后台线程执行，
/// 通过 `await` 跳回 `@MainActor` 执行写操作，保证线程安全。
@MainActor
public protocol MessageStreaming: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前正在流式的临时行（最多一条）。
    ///
    /// 非 nil 时 UI 把它拼到 messages 末尾渲染；nil 时表示无流式进行。
    /// 其 id 始终是 `Self.streamingRowID`（进程级常量），SwiftUI diff 稳定。
    var currentStreamingRow: LumiChatMessage? { get }

    /// 开始一次流式：创建一条空临时 assistant 行（稳定 id）。
    func startStreaming(conversationID: UUID) async

    /// 追加正文增量，更新临时行的 content。
    func appendContent(_ piece: String) async

    /// 追加思考增量，更新临时行的 reasoningContent。
    func appendThinking(_ piece: String) async

    /// 结束流式：清空临时行。
    ///
    /// 最终落库行由 UI 的 messagesDidChange 自然刷新显示，
    /// 因 id 不同，临时行消失与真实行出现是两次独立 diff，UI 无需协调。
    func endStreaming() async
}

/// 流式临时行使用的进程级**稳定常量 id**。
///
/// 一次性生成、跨整个进程稳定不变：SwiftUI 的 ForEach diff 稳定，
/// 且永远不会与任何落库消息（UUID 随机生成）冲突。
/// 实现 `MessageStreaming` 的 store 在 `startStreaming` 时用它创建临时行，
/// UI 拼接渲染时据此 id 识别流式行。
public let LumiStreamingRowID = UUID()
