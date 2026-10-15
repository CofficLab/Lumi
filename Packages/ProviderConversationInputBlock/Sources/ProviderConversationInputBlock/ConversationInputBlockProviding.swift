import Foundation

/// A block of content that a plugin wants to hand to the conversation input as a
/// single collapsed chip instead of inline plain text.
///
/// Producers describe *what* the content is (title, symbol) and keep the full
/// text out of the draft until the user actually sends it. The input plugin owns
/// how a block is rendered, so this type stays free of any UI or editor concern.
@MainActor
public struct ConversationInputBlock: Equatable, Sendable {
    /// Stable identity, used to deduplicate repeated requests for the same block.
    public let id: UUID
    /// Full text that the input will submit when the user sends the message.
    public let text: String
    /// One-line summary rendered on the inline chip.
    public let title: String
    /// SF Symbol name drawn on the chip, so the user can tell the block's origin.
    public let systemImage: String
    /// Minimum text length before the input collapses this block into a chip.
    ///
    /// Shorter text is inserted as plain text so the user can still edit it
    /// directly before sending. `0` forces collapsing for any non-empty text.
    public let collapseThreshold: Int

    public init(
        id: UUID = UUID(),
        text: String,
        title: String,
        systemImage: String = "doc.on.clipboard",
        collapseThreshold: Int = 0
    ) {
        self.id = id
        self.text = text
        self.title = title
        self.systemImage = systemImage
        self.collapseThreshold = max(0, collapseThreshold)
    }

    /// Whether the input should collapse this block rather than insert raw text.
    public var shouldCollapse: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count >= collapseThreshold
    }
}

/// 折叠内容块变化事件。
@MainActor
public enum ConversationInputBlockProvidingEvent: Equatable, Sendable {
    /// 生产方提交了一个待插入输入框的块。
    case blockSubmitted(ConversationInputBlock)
}

/// 折叠内容块观察句柄。
@MainActor
public protocol ConversationInputBlockObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class NoopConversationInputBlockObserverHandle: ConversationInputBlockObserverHandle {
    public init() {}
    public func cancel() {}
}

/// 跨插件递交「折叠内容块」的能力。
///
/// 生产方（如代码编辑器把选区发送到对话）只负责描述内容，不关心输入框如何
/// 渲染；输入插件是唯一的消费者，负责按 `collapseThreshold` 决定折叠成内联
/// chip 还是按纯文本插入，并在发送时还原成完整文本。
@MainActor
public protocol ConversationInputBlockProviding: AnyObject {
    /// 递交一个待插入输入框的块。
    func submit(_ block: ConversationInputBlock)

    /// 注册折叠内容块观察者。回调在主线程同步执行。
    @discardableResult
    func addObserver(
        _ callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) -> any ConversationInputBlockObserverHandle
}