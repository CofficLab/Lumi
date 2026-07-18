import Foundation
import LumiComponentMessage

@MainActor
final class ConversationStatusState {
    private var statusMessageByConversationID: [UUID: LumiChatMessage] = [:]
    private var stableStatusRowIDByConversationID: [UUID: UUID] = [:]
    private var thinkingTextBufferByConversationID: [UUID: String] = [:]
    private var streamingTextBufferByConversationID: [UUID: String] = [:]

    private static let statusTailBufferMax = 20

    func statusMessage(for conversationID: UUID) -> LumiChatMessage? {
        statusMessageByConversationID[conversationID]
    }

    func setStatus(conversationID: UUID, content: String) {
        let rowID = stableStatusRowIDByConversationID[conversationID] ?? {
            let id = UUID()
            stableStatusRowIDByConversationID[conversationID] = id
            return id
        }()
        statusMessageByConversationID[conversationID] = LumiChatMessage(
            id: rowID,
            conversationID: conversationID,
            role: .status,
            content: content,
            metadata: ["isTransientStatus": "true"]
        )
    }

    func clearStatus(conversationID: UUID) {
        statusMessageByConversationID[conversationID] = nil
        stableStatusRowIDByConversationID[conversationID] = nil
        thinkingTextBufferByConversationID[conversationID] = nil
        streamingTextBufferByConversationID[conversationID] = nil
    }

    func applyStreamChunk(conversationID: UUID, chunk: LumiStreamChunk) {
        if chunk.isDone {
            thinkingTextBufferByConversationID[conversationID] = nil
            streamingTextBufferByConversationID[conversationID] = nil
            setStatus(conversationID: conversationID, content: "结束")
            return
        }

        if chunk.isThinking {
            thinkingTextBufferByConversationID[conversationID, default: ""] += chunk.content ?? ""
            thinkingTextBufferByConversationID[conversationID] = Self.normalizedStatusTailBuffer(
                from: thinkingTextBufferByConversationID[conversationID] ?? ""
            )
            let accumulated = thinkingTextBufferByConversationID[conversationID] ?? ""
            let title = chunk.eventTitle.isEmpty ? "思考中" : chunk.eventTitle
            setStatus(
                conversationID: conversationID,
                content: Self.statusLineWithTailPreview(accumulated: accumulated, title: title)
            )
            return
        }

        if let content = chunk.content, !content.isEmpty {
            streamingTextBufferByConversationID[conversationID, default: ""] += content
            streamingTextBufferByConversationID[conversationID] = Self.normalizedStatusTailBuffer(
                from: streamingTextBufferByConversationID[conversationID] ?? ""
            )
            let accumulated = streamingTextBufferByConversationID[conversationID] ?? ""
            setStatus(
                conversationID: conversationID,
                content: Self.statusLineWithTailPreview(accumulated: accumulated, title: chunk.eventTitle)
            )
            return
        }

        setStatus(conversationID: conversationID, content: "\(chunk.eventTitle)...")
    }

    func setToolProgress(conversationID: UUID, toolName: String, elapsedSeconds: Int, outputPreview: String?) {
        var line = "\(toolName)（\(max(0, elapsedSeconds))s"
        if let outputPreview, !outputPreview.isEmpty {
            line += "，最近输出：\(outputPreview)"
        }
        line += "）"
        setStatus(conversationID: conversationID, content: line)
    }

    func setToolCompleted(conversationID: UUID, toolName: String, elapsedSeconds: Int?) {
        let durationSuffix = elapsedSeconds.map { "（\(max(0, $0))s）" } ?? ""
        setStatus(conversationID: conversationID, content: "\(toolName)\(durationSuffix)")
    }

    private static func normalizedStatusTailBuffer(from raw: String) -> String {
        let normalized = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        if normalized.count <= statusTailBufferMax {
            return normalized
        }
        return String(normalized.suffix(statusTailBufferMax))
    }

    private static func statusLineWithTailPreview(accumulated: String, title: String) -> String {
        if accumulated.isEmpty {
            return "\(title)..."
        }
        return "\(title)：\(accumulated)"
    }
}
