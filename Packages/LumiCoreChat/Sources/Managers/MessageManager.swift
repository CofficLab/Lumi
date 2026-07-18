import Foundation
import LumiCoreMessage

/// Manages message operations: CRUD, pagination, merging, notifications.
@MainActor
final class MessageManager {
    private weak var service: ChatService?

    init(service: ChatService) {
        self.service = service
    }

    // MARK: - Read

    func messages(for conversationID: UUID) -> [LumiChatMessage] {
        service?.messagesByConversationID[conversationID] ?? []
    }

    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] {
        var result = messages(for: conversationID).filter {
            $0.role != .status || $0.renderKind == "turn-completed"
        }
        if let status = service?.statusState.statusMessage(for: conversationID) {
            result.append(status)
        }
        return result
    }

    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] {
        let allMessages = messages(for: conversationID).filter { $0.role != .status && $0.role != .tool }
        guard !allMessages.isEmpty else {
            return []
        }

        let endIndex: Int
        if let beforeMessageID,
           let index = allMessages.firstIndex(where: { $0.id == beforeMessageID }) {
            endIndex = index
        } else {
            endIndex = allMessages.count
        }

        let startIndex = max(0, endIndex - limit)
        return Array(allMessages[startIndex..<endIndex])
    }

    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool {
        let allMessages = messages(for: conversationID).filter { $0.role != .status && $0.role != .tool }
        guard let beforeMessageID,
              let index = allMessages.firstIndex(where: { $0.id == beforeMessageID })
        else {
            return allMessages.count > (service?.defaultPageSize ?? 10)
        }
        return index > 0
    }

    // MARK: - Write

    func append(_ message: LumiChatMessage) {
        guard let service else { return }

        if message.role == .status, message.renderKind != "turn-completed" {
            return
        }
        service.messagesByConversationID[message.conversationID, default: []].append(message)
        updateConversationSummary(for: message)
        // 增量持久化：只保存这条消息 + 对话预览更新
        service.persistMessage(message)
        if let updatedConversation = service.conversations.first(where: { $0.id == message.conversationID }) {
            service.store.upsertConversation(updatedConversation)
        }
        postMessageSavedNotification(for: message)
    }

    func deleteMessage(id: UUID, in conversationID: UUID) {
        guard let service,
              var messages = service.messagesByConversationID[conversationID]
        else {
            return
        }
        messages.removeAll { $0.id == id }
        service.messagesByConversationID[conversationID] = messages
        // 增量删除：只删除这一条消息
        service.persistDeleteMessage(id: id)
    }

    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        conversationID: UUID
    ) {
        guard let service,
              var messages = service.messagesByConversationID[conversationID],
              let messageIndex = messages.firstIndex(where: { $0.id == assistantMessageID }),
              var toolCalls = messages[messageIndex].toolCalls,
              let toolCallIndex = toolCalls.firstIndex(where: { $0.id == toolCallID })
        else {
            return
        }

        toolCalls[toolCallIndex].result = result
        messages[messageIndex].toolCalls = toolCalls
        service.messagesByConversationID[conversationID] = messages
        // 增量持久化：只更新这条消息
        service.persistMessage(messages[messageIndex])
    }

    /// 回填工具调用的用户友好描述（displayName）。
    ///
    /// 在执行工具之前调用，使界面在「加载中」与「已完成」两种状态下都能展示
    /// 由工具自身生成的、带参数语义的描述（如「读取 Foo.swift」），而非原始工具名。
    /// 跳过已经设置过 displayName 的调用，避免重复持久化。
    func updateToolCallDisplayName(
        _ displayName: String,
        toolCallID: String,
        assistantMessageID: UUID,
        conversationID: UUID
    ) {
        guard let service,
              var messages = service.messagesByConversationID[conversationID],
              let messageIndex = messages.firstIndex(where: { $0.id == assistantMessageID }),
              var toolCalls = messages[messageIndex].toolCalls,
              let toolCallIndex = toolCalls.firstIndex(where: { $0.id == toolCallID }),
              toolCalls[toolCallIndex].displayName != displayName
        else {
            return
        }

        toolCalls[toolCallIndex].displayName = displayName
        messages[messageIndex].toolCalls = toolCalls
        service.messagesByConversationID[conversationID] = messages
        // 增量持久化：只更新这条消息
        service.persistMessage(messages[messageIndex])
    }

    // MARK: - Notifications

    func postMessageSavedNotification(for message: LumiChatMessage) {
        // 唯一发送方：`.lumiMessageSaved`。
        NotificationCenter.default.post(
            name: .lumiMessageSaved,
            object: nil,
            userInfo: [
                LumiMessageSavedNotification.messageIDKey: message.id,
                LumiMessageSavedNotification.conversationIDKey: message.conversationID,
                LumiMessageSavedNotification.roleKey: message.role.rawValue
            ]
        )
    }

    // MARK: - Conversation Summary Update

    private func updateConversationSummary(for message: LumiChatMessage) {
        guard let service,
              let index = service.conversations.firstIndex(where: { $0.id == message.conversationID })
        else {
            return
        }

        var conversation = service.conversations[index]
        conversation.preview = message.content
        conversation.updatedAt = message.createdAt

        if conversation.title == "New Chat", message.role == .user {
            conversation.title = service.title(from: message.content)
        }

        service.conversations.remove(at: index)
        service.conversations.insert(conversation, at: 0)
    }

    // MARK: - Merging & Utilities

    static func messagesByMergingToolResults(
        _ messagesByConversationID: [UUID: [LumiChatMessage]]
    ) -> [UUID: [LumiChatMessage]] {
        messagesByConversationID.mapValues { messages in
            var merged = messages
            var assistantIndexByToolCallID: [String: Int] = [:]

            for index in merged.indices {
                guard merged[index].role == .assistant,
                      let toolCalls = merged[index].toolCalls
                else {
                    continue
                }

                for toolCall in toolCalls {
                    assistantIndexByToolCallID[toolCall.id] = index
                }
            }

            for message in messages where message.role == .tool {
                guard let toolCallID = message.toolCallID,
                      let assistantIndex = assistantIndexByToolCallID[toolCallID],
                      var toolCalls = merged[assistantIndex].toolCalls,
                      let toolCallIndex = toolCalls.firstIndex(where: { $0.id == toolCallID }),
                      toolCalls[toolCallIndex].result == nil
                else {
                    continue
                }

                toolCalls[toolCallIndex].result = LumiToolResult(
                    content: message.content,
                    isError: message.isError
                )
                merged[assistantIndex].toolCalls = toolCalls
            }

            return merged
        }
    }

    static func messagesWithImageContext(
        _ messages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment]
    ) -> [LumiChatMessage] {
        guard !imageAttachments.isEmpty else {
            return messages
        }

        return messages.map { message in
            guard message.role == .user else {
                return message
            }

            var updated = message
            var metadata = updated.metadata
            metadata["hasImages"] = "true"
            if let encoded = encodeImageAttachments(imageAttachments) {
                metadata["imageAttachments"] = encoded
            }
            updated.metadata = metadata

            if updated.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.content = "[\(imageAttachments.count) image(s) attached]"
            }
            return updated
        }
    }

    static func encodeImageAttachments(_ attachments: [LumiImageAttachment]) -> String? {
        guard let data = try? JSONEncoder().encode(attachments),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }
}
