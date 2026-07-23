import Combine
import Foundation

/// 消息发送能力协议
///
/// 定义「用户输入 → 内核 → 落库 / 派发」这一段的最小契约。
/// 具体的发送策略（同步落库、异步排队、走 LLM、流式回复……）
/// 由实现方决定；本协议只规定调用方需要看到的能力。
///
/// 命名约定：本协议以 "Managing" 结尾，遵循 Kernel 中
/// `ConversationManaging` / `MessageManaging` 的命名风格。
///
/// ## 实现契约
/// 实现 `sendMessage(_:conversationID:)` 时**必须**做以下事情：
/// 1. 对 `content` 做 `trim`；trim 后为空则直接 return,不抛错。
/// 2. 解析目标会话：`conversationID` 非 nil 时使用它;为 nil 时
///    取 `kernel.conversations?.selectedConversationID`。
///    两者皆无 → 抛 `LumiKernelError.noActiveConversation`。
/// 3. 构造一条 `LumiChatMessage(role: .user, content: ...)` 并通过
///    `kernel.messageManager?.insertMessage(_:to:)` 落库到消息历史。
/// 4. （可选）触发下游行为：例如异步调用 LLM、流式回复、Agent loop 等。
///    本协议**不**规定这些行为的细节;mock 实现可以只完成第 1-3 步。
@MainActor
public protocol MessageSending: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 是否有正在进行的发送任务
    var isSending: Bool { get }

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

    // MARK: - 发送

    /// text-only 发送的便利方法(向后兼容)
    ///
    /// 默认实现会把当前 `pendingAttachments` 作为本次发送的附件,然后转发到
    /// `sendMessage(_:imageAttachments:conversationID:)`。
    /// - Parameter content: 用户输入的文本。**由实现负责 trim 并校验非空**。
    /// - Parameter conversationID: 目标会话 ID。`nil` 表示"由实现选取当前会话";
    ///   若当前没有选中会话,实现应抛出 `LumiKernelError.noActiveConversation`。
    ///   **本协议不负责自动创建会话** — 调用方应先
    ///   `kernel.conversations?.createConversation(title: nil)` 拿到一个 ID 再传入。
    /// - Throws: `LumiKernelError.noActiveConversation` 当没有可用会话时
    func sendMessage(_ content: String, conversationID: UUID?) async throws

    /// 文本 + 显式图片附件的发送
    ///
    /// 实现应:
    /// 1. trim `content`,trim 后为空则直接 return,不抛错;
    /// 2. 解析目标会话(`conversationID` 非 nil 使用它,否则
    ///    `kernel.conversations?.selectedConversationID`,否则自动创建);
    /// 3. 构造 `LumiChatMessage(role: .user, content: ..., metadata: ...)` 并通过
    ///    `kernel.messageManager?.insertMessage(_:to:)` 落库;若 `imageAttachments`
    ///    非空,应编码为 JSON 写入 `metadata["imageAttachments"]`;
    /// 4. 触发 `kernel.agentTurnRunner?.runTurn(in:)` 执行完整 agent loop。
    /// - Parameter content: 用户输入文本(由实现 trim)
    /// - Parameter imageAttachments: 本次随文本一起送出的图片附件;为 `[]` 时等同纯文本
    /// - Parameter conversationID: 同上
    func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        conversationID: UUID?
    ) async throws

    /// 取消当前正在进行的发送任务
    func cancelCurrentRequest()
}

// MARK: - 默认实现

public extension MessageSending {
    /// text-only 路径的默认转发:复用当前 `pendingAttachments` 作为本次发送的附件。
    /// 具体实现可在重写时自由决定是否清空 `pendingAttachments`(默认行为:不清空)。
    func sendMessage(_ content: String, conversationID: UUID?) async throws {
        try await sendMessage(
            content,
            imageAttachments: pendingAttachments,
            conversationID: conversationID
        )
    }
}
