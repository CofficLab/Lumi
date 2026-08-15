import AgentToolKit
import Foundation
import KernelLumi
import KernelLumi
import KernelLumi

extension LumiToolCall {
    /// Bridges `LumiToolCall` to AgentToolKit's registry-facing `ToolCall` model.
    var agentToolCall: ToolCall {
        ToolCall(
            id: id,
            name: name,
            arguments: arguments,
            result: result.map { lumiResult in
                ToolCallResult(
                    content: lumiResult.content,
                    isError: lumiResult.isError,
                    duration: lumiResult.duration,
                    awaitingUserResponse: lumiResult.turnControl.isSuspended,
                    interactionState: Self.interactionState(for: lumiResult.turnControl)
                )
            },
            displayDescription: displayDescription
        )
    }

    private static func interactionState(for control: AgentTurnControl) -> ToolCallInteractionState? {
        switch control {
        case .continueTurn:
            return nil
        case .suspend:
            return .waiting
        case let .resumed(_, answer):
            return .answered(answer)
        }
    }
}

extension LumiChatMessage {
    func decodedImageAttachments() -> [LumiImageAttachment] {
        LumiImageAttachmentMetadata.decode(from: metadata)
    }

    var userImageData: [Data] {
        decodedImageAttachments().compactMap { Data(base64Encoded: $0.base64Data) }
    }

    /// 该消息携带的文件附件(解码自 metadata["fileAttachments"])。
    var decodedFileAttachments: [LumiFileAttachment] {
        LumiFileAttachmentMetadata.decode(from: metadata)
    }

    /// 解码结果缓存取用:消息行的 body 求值(含 List 滚动重物化)历史上
    /// 每次都对 metadata 做 JSON 解析 + base64 解码(图片附件可观的重复开销)。
    /// 附件随消息落库后不变,按消息 id 进程级缓存。
    var cachedDecodedAttachments: MessageAttachmentDecodeCache.Decoded {
        MessageAttachmentDecodeCache.shared.decoded(for: self)
    }
}

/// 用户消息附件解码结果的进程级缓存(锁保护,有界)。
///
/// 假设:附件随消息落库后不再变化(应用内消息为 append-only)。
final class MessageAttachmentDecodeCache: @unchecked Sendable {
    static let shared = MessageAttachmentDecodeCache()

    struct Decoded {
        let imageData: [Data]
        let fileAttachments: [LumiFileAttachment]
    }

    private let limit = 64
    private let lock = NSLock()
    private var storage: [UUID: Decoded] = [:]
    private var insertionOrder: [UUID] = []

    func decoded(for message: LumiChatMessage) -> Decoded {
        lock.lock()
        if let cached = storage[message.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // 解码在锁外执行,不阻塞并发的缓存查询
        let images = message.decodedImageAttachments()
            .compactMap { Data(base64Encoded: $0.base64Data) }
        let files = LumiFileAttachmentMetadata.decode(from: message.metadata)
        let decoded = Decoded(imageData: images, fileAttachments: files)

        lock.lock()
        defer { lock.unlock() }
        if storage[message.id] == nil {
            insertionOrder.append(message.id)
        }
        storage[message.id] = decoded
        if insertionOrder.count > limit {
            let overflow = insertionOrder.count - limit
            for id in insertionOrder.prefix(overflow) {
                storage.removeValue(forKey: id)
            }
            insertionOrder.removeFirst(overflow)
        }
        return decoded
    }
}
