import Combine
import Foundation

/// 消息发送能力协议
///
/// 定义「用户输入 → 内核 → 落库 / 派发」这一段的最小契约。
/// 具体的发送策略（同步落库、异步排队、走 LLM、流式回复……）
/// 由实现方决定；本协议只规定调用方需要看到的能力。
@MainActor
public protocol MessageSending: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 是否存在任意正在进行的发送任务。
    var isSending: Bool { get }

    /// 指定对话是否正在发送中。
    ///
    /// - Parameter conversationID: 目标对话 ID。传 `nil` 时返回任意对话是否处于发送中。
    func isSending(for conversationID: UUID?) -> Bool

    /// Messages waiting to be sent after the current turn in a conversation.
    func pendingMessages(for conversationID: UUID) -> [LumiPendingMessage]

    /// Remove one queued message without starting a turn for it.
    func cancelPendingMessage(id: UUID, in conversationID: UUID)

    // MARK: - 附件挂起池(可观察、可修改)

    /// 当前挂起、等待下次发送时随消息一起送出的图片附件
    ///
    /// 由实现以 `@Published` 暴露,UI 层可直接 `ObservedObject` 订阅以渲染缩略图列表。
    /// 调用 `sendMessage(_:conversationID:)`(text-only 重载)时,
    /// 默认实现会把当前 `pendingAttachments` 作为本次发送的附件。
    /// 想发送不同于挂起池的附件(例如工具结果图片),应显式调用
    /// `sendMessage(_:imageAttachments:conversationID:)` 重载。
    var pendingAttachments: [LumiImageAttachment] { get }

    /// 添加一个附件到挂起池
    ///
    /// **契约**:幂等。若池中已存在相同 `id` 的附件则忽略,不会重复添加。
    /// - Parameter attachment: 待加入的附件
    func addAttachment(_ attachment: LumiImageAttachment)

    /// 按 `id` 移除一个挂起附件
    ///
    /// - Parameter id: 要移除的附件 id。id 不存在时为 no-op,不抛错。
    func removeAttachment(id: UUID)

    /// 清空所有挂起附件
    func clearAttachments()

    // MARK: - 文件附件挂起池(可观察、可修改)

    /// 当前挂起、等待下次发送时随消息一起送出的**文件**附件。
    ///
    /// 与 `pendingAttachments`(图片)并行的另一条链路:支持任意文件。
    /// 文本类文件的正文会在发送时注入用户消息;二进制文件仅作可见 chip。
    /// 由实现以 `@Published` 暴露。
    var pendingFileAttachments: [LumiFileAttachment] { get }

    /// 添加一个文件附件到挂起池(幂等:同 `id` 已存在则忽略)。
    func addFileAttachment(_ attachment: LumiFileAttachment)

    /// 按 `id` 移除一个挂起文件附件(id 不存在时为 no-op)。
    func removeFileAttachment(id: UUID)

    /// 清空所有挂起文件附件。
    func clearFileAttachments()

    // MARK: - 发送

    /// text-only 发送的便利方法(向后兼容)
    ///
    /// 默认实现会把当前 `pendingAttachments` 作为本次发送的附件,然后转发到
    /// `sendMessage(_:imageAttachments:conversationID:)`。
    /// - Parameter content: 用户输入的文本。**由实现负责 trim 并校验非空**。
    /// - Parameter conversationID: 目标会话 ID。`nil` 表示"由实现选取当前会话";
    ///   若当前没有选中会话,实现应抛出 `KernelLumiError.noActiveConversation`。
    ///   **本协议不负责自动创建会话** — 调用方应先
    ///   `kernel.conversations?.createConversation(title: nil)` 拿到一个 ID 再传入。
    /// - Throws: `KernelLumiError.noActiveConversation` 当没有可用会话时
    func sendMessage(_ content: String, conversationID: UUID?) async throws

    /// 文本 + 显式图片附件的发送
    ///
    /// 实现应:
    /// 1. trim `content`,trim 后为空则直接 return,不抛错;
    /// 2. 解析目标会话(`conversationID` 非 nil 使用它,否则
    ///    `kernel.conversations?.selectedConversationID`,否则自动创建);
    /// 3. 构造 `LumiChatMessage(role: .user, content: ..., metadata: ...)` 并通过
    ///    `kernel.messageManager?.insertMessage(_:to:)` 落库;若 `imageAttachments`
    ///    非空,应编码为 JSON 写入 `metadata["imageAttachments"]`;此外,实现通常会把
    ///    当前 `pendingFileAttachments` 也编码进 `metadata["fileAttachments"]`(文件链路);
    /// 4. 触发 `kernel.agentTurnManager?.runTurn(in:)` 执行完整 agent loop。
    /// - Parameter content: 用户输入文本(由实现 trim)
    /// - Parameter imageAttachments: 本次随文本一起送出的图片附件;为 `[]` 时等同纯文本
    /// - Parameter conversationID: 同上
    func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        conversationID: UUID?
    ) async throws

    /// Resume a suspended agent turn while preserving the sender lifecycle.
    ///
    /// Implementations that expose agent-turn resumption should keep the target
    /// conversation in the sending state for the duration of the resumed turn,
    /// so UI consumers observe the same transient status as a normal send.
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome

    /// Continue an existing conversation without inserting a user message.
    ///
    /// This is used by system-owned workflows such as Goal continuation. The
    /// implementation must keep the conversation in the sending state while
    /// the resumed turn is running.
    func continueTurn(in conversationID: UUID)

    /// 取消当前正在进行的发送任务
    func cancelCurrentRequest()

    /// 重新发送已保存的用户消息。
    ///
    /// 实现应复用原消息的正文和附件 metadata,并在同一对话中触发新的 agent turn。
    /// 找不到消息、消息不是 user role、或该对话正在发送时应 no-op。
    func resendMessage(id: UUID, in conversationID: UUID) async
}

// MARK: - 默认实现

public extension MessageSending {
    func pendingMessages(for conversationID: UUID) -> [LumiPendingMessage] { [] }

    func cancelPendingMessage(id: UUID, in conversationID: UUID) {}

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome {
        throw AgentTurnManagingError.resumeNotSupported
    }

    func continueTurn(in conversationID: UUID) {}

    func isSending(for conversationID: UUID?) -> Bool {
        guard conversationID != nil else { return isSending }
        return isSending
    }

    /// text-only 路径的默认转发:复用当前 `pendingAttachments` 作为本次发送的图片附件。
    /// (文件附件 `pendingFileAttachments` 不走此重载签名,由具体实现如 `MessageSender`
    /// 在落库时直接读取自己的文件挂起池并序列化进 metadata。)
    /// 具体实现可在重写时自由决定是否清空挂起池(默认行为:不清空)。
    func sendMessage(_ content: String, conversationID: UUID?) async throws {
        try await sendMessage(
            content,
            imageAttachments: pendingAttachments,
            conversationID: conversationID
        )
    }

    func resendMessage(id: UUID, in conversationID: UUID) async {}
}
