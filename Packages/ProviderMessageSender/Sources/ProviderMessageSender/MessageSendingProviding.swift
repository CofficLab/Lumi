import Combine
import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 发送状态变化观察者的注册令牌。
///
/// 调用 `MessageSendingProviding.addSendingStateObserver(_:)` 后持有返回值
/// 即可持续接收发送状态变化通知；令牌释放（deinit）或显式调用 `cancel()` 时
/// 自动停止接收，无需手动反注册。
@MainActor
public protocol SendingStateObserverHandle: AnyObject {
    /// 停止接收发送状态变化通知。重复调用无副作用。
    func cancel()
}

/// 消息发送能力协议（KernelCore 体系）。
///
/// 复刻旧版 `MessageSending` 的职责（对齐 `Plugins/MessageSenderPlugin`）：
/// - 发送：trim → 解析目标会话 → 落库 user 消息 → 交给 AgentLoop 执行回合；
/// - 附件：图片 / 文件附件挂起池，随下一条消息一起送出，编码进 metadata；
/// - 排队：同一会话发送中时，新消息进入 pending 队列，完成后依次发出；
/// - 取消 / 恢复：`cancelCurrentRequest` 取消当前回合；`resumeTurn` 恢复挂起回合。
@MainActor
public protocol MessageSendingProviding: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var isSending: Bool { get }

    // MARK: - Observation

    /// 注册一个观察者：当 `isSending` 变化时通过 callback 收到最新状态。
    ///
    /// 回调在主线程同步执行。仅当状态实际发生变化时触发。
    ///
    /// - Parameter callback: 发送状态变化时的通知回调，参数为最新 `isSending` 值。
    /// - Returns: 注销令牌；持有返回值即可持续接收，令牌释放或调用 `cancel()` 后自动停止。
    @discardableResult
    func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle

    // MARK: - Attachments（挂起池）

    /// 当前挂起、等待下次发送时随消息一起送出的图片附件。
    var pendingImageAttachments: [UserImageAttachment] { get }
    /// 当前挂起、等待下次发送时随消息一起送出的文件附件。
    var pendingFileAttachments: [UserFileAttachment] { get }

    func addImageAttachment(_ attachment: UserImageAttachment)
    func removeImageAttachment(id: UUID)
    func clearImageAttachments()
    func addFileAttachment(_ attachment: UserFileAttachment)
    func removeFileAttachment(id: UUID)
    func clearFileAttachments()

    // MARK: - Pending Queue

    /// 指定会话的待发送消息队列（发送中时新消息入队）。
    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage]
    func cancelPendingMessage(id: UUID, in conversationID: UUID)

    // MARK: - Send

    func sendMessage(_ content: String, conversationID: UUID?) async throws
    func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws
    func cancelCurrentRequest()

    // MARK: - Resume

    /// 恢复被工具授权/提问挂起的回合（用户已作答）。
    @discardableResult
    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome
}

/// 待发送消息（队列条目）。
public struct PendingChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let content: String
    public let imageAttachments: [UserImageAttachment]
    public let fileAttachments: [UserFileAttachment]

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        content: String,
        imageAttachments: [UserImageAttachment] = [],
        fileAttachments: [UserFileAttachment] = []
    ) {
        self.id = id
        self.conversationID = conversationID
        self.content = content
        self.imageAttachments = imageAttachments
        self.fileAttachments = fileAttachments
    }
}
