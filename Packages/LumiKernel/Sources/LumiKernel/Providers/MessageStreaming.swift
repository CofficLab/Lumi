import Combine
import Foundation

/// 流式输出能力协议（runner 写、UI 读）。
///
/// 按会话持有正在流式的临时 assistant 行，全程不查库。
/// 临时行用进程级**稳定常量 id**（`streamingRowID`），与最终落库行 id 永不冲突，
/// UI 在渲染时把对应会话的临时行拼到 `messages` 末尾即可。
///
/// 同时维护每个会话当前回合的阶段，供"发送中"状态行展示阶段性文案
/// （发送/思考/生成…），而非固定文案。
///
/// 调用约定：所有写方法标 `async`。runner 的 `onChunk` 在 provider 后台线程执行，
/// 通过 `await` 跳回 `@MainActor` 执行写操作，保证线程安全。
@MainActor
public protocol MessageStreaming: ObservableObject, Sendable where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 返回指定会话正在流式的临时行。每个会话互相隔离。
    func streamingRow(for conversationID: UUID) -> LumiChatMessage?

    /// 返回指定会话当前回合所处的阶段。
    func streamingStage(for conversationID: UUID) -> ChatStage

    /// 开始一次流式：创建一条空临时 assistant 行（稳定 id），阶段置为 `.sending`。
    func startStreaming(conversationID: UUID) async

    /// 追加指定会话的正文增量，更新临时行的 content，阶段置为 `.generating`。
    func appendContent(_ piece: String, conversationID: UUID) async

    /// 追加指定会话的思考增量，更新临时行的 reasoningContent，阶段置为 `.thinking`。
    func appendThinking(_ piece: String, conversationID: UUID) async

    /// 结束指定会话的流式：清空该会话临时行，阶段置为 `.idle`。
    ///
    /// 最终落库行由 UI 的 messagesDidChange 自然刷新显示，
    /// 因 id 不同，临时行消失与真实行出现是两次独立 diff，UI 无需协调。
    func endStreaming(conversationID: UUID) async
}

/// 流式临时行使用的进程级**稳定常量 id**。
///
/// 一次性生成、跨整个进程稳定不变：SwiftUI 的 ForEach diff 稳定，
/// 且永远不会与任何落库消息（UUID 随机生成）冲突。
/// 实现 `MessageStreaming` 的 store 在 `startStreaming` 时用它创建临时行，
/// UI 拼接渲染时据此 id 识别流式行。
public let LumiStreamingRowID = UUID()
