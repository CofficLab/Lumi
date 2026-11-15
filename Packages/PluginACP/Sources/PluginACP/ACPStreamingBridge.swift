import Foundation
import ProviderMessage

/// 回合内流式文本的观察窄协议。
///
/// 生产环境由 `MessageStreamingProviding`（PluginMessageStreaming）满足；
/// 测试注入轻量 mock。
@MainActor
public protocol ACPStreamObserving: AnyObject {
    /// 订阅流式更新；每次增量（内容或思考）触发一次。
    func addACPStreamObserver(
        _ callback: @escaping (UUID) -> Void
    ) -> any ACPStreamObserverHandle

    /// 当前流式消息的正文（无流式行为时返回 nil）。
    func acpStreamingContent(for conversationID: UUID) -> String?

    /// 当前流式消息的身份标识。
    ///
    /// 底层每次 `start` 都新建一条流式消息（独立 id）；一个 ACP 回合内
    /// 「LLM → 工具 → LLM」会产生多条消息。桥据此为每条消息使用独立的发送
    /// 偏移，避免第二段沿用第一段的偏移被截断或整段丢弃（#351）。
    func acpStreamingMessageID(for conversationID: UUID) -> UUID?
}

/// 流式观察者注销令牌。
@MainActor
public protocol ACPStreamObserverHandle: AnyObject {
    func cancel()
}

/// 流式文本 → `session/update(agent_message_chunk)` 的增量桥。
///
/// 内核在回合进行中持续把 token 追加到流式 store；这里订阅该变化，只把
/// **新增的尾部片段**作为增量帧发出，使编辑器能实时渲染。
///
/// 去重约定：一旦某个会话成功发出过增量，回合收尾时就不再重复发送整段
/// 最终文本（`ACPTurnCoordinator` 依据 `didStream(sessionID:)` 决定）。
@MainActor
public final class ACPStreamingBridge {
    private let stream: any ACPStreamObserving
    private var handle: (any ACPStreamObserverHandle)?
    /// 已发出的正文长度（用于计算增量）。
    private var sentLength: [UUID: Int] = [:]
    /// 最近一次发送增量所属的流式消息 id；变化即代表底层 `start` 了新消息。
    private var streamMessageID: [UUID: UUID] = [:]

    /// 流式增量回调（已计算好的新片段 + 对话 ID）。
    var onDelta: ((UUID, String) -> Void)?

    init(stream: any ACPStreamObserving) {
        self.stream = stream
        handle = stream.addACPStreamObserver { [weak self] conversationID in
            self?.flush(conversationID: conversationID)
        }
    }

    /// 停止观察（回合/连接结束时显式调用；令牌为 MainActor 隔离，不能在 deinit 访问）。
    func stopObserving() {
        handle?.cancel()
        handle = nil
    }

    /// 该会话是否已通过流式发出过内容。
    func didStream(conversationID: UUID) -> Bool {
        (sentLength[conversationID] ?? 0) > 0
    }

    /// 清理会话状态（回合收尾时调用）。
    func reset(conversationID: UUID) {
        sentLength.removeValue(forKey: conversationID)
        streamMessageID.removeValue(forKey: conversationID)
    }

    /// 把当前流式正文相对上次的增量发出去。
    private func flush(conversationID: UUID) {
        guard let content = stream.acpStreamingContent(for: conversationID) else { return }
        // 底层 `start` 新消息时正文重置为空、id 变化。检测到新消息就把发送
        // 偏移归零，否则第二段响应会沿用第一段的偏移：更短则整段丢弃，更长
        // 则只发后缀（#351）。用消息身份而非长度判定，等长不同正文也能完整发出。
        if let messageID = stream.acpStreamingMessageID(for: conversationID),
           streamMessageID[conversationID] != messageID {
            streamMessageID[conversationID] = messageID
            sentLength[conversationID] = 0
        }
        let alreadySent = sentLength[conversationID] ?? 0
        guard content.count > alreadySent else { return }
        let start = content.index(content.startIndex, offsetBy: alreadySent)
        let delta = String(content[start...])
        guard !delta.isEmpty else { return }
        sentLength[conversationID] = content.count
        onDelta?(conversationID, delta)
    }
}
