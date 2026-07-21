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
public protocol MessageSendManaging: ObservableObject {
    /// 是否有正在进行的发送任务
    var isSending: Bool { get }

    /// 发送一条用户消息
    ///
    /// - Parameter content: 用户输入的文本。**由实现负责 trim 并校验非空**。
    /// - Parameter conversationID: 目标会话 ID。`nil` 表示"由实现选取当前会话";
    ///   若当前没有选中会话,实现应抛出 `LumiKernelError.noActiveConversation`。
    ///   **本协议不负责自动创建会话** — 调用方应先
    ///   `kernel.conversations?.createConversation(title: nil)` 拿到一个 ID 再传入。
    /// - Throws: `LumiKernelError.noActiveConversation` 当没有可用会话时
    func sendMessage(_ content: String, conversationID: UUID?) async throws

    /// 取消当前正在进行的发送任务
    func cancelCurrentRequest()
}
