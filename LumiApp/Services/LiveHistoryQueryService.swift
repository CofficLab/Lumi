import Foundation
import LumiCoreKit
import SwiftData

/// 历史数据查询服务的内核实现
///
/// 桥接 `HistoryQueryService` 协议与 `ChatHistoryService` 的 SwiftData 操作。
/// 所有查询在主线程执行，返回轻量 DTO，不暴露 Entity 细节给插件层。
@MainActor
final class LiveHistoryQueryService: HistoryQueryService, Sendable {
    private let chatHistoryService: ChatHistoryService
    private let conversationService: ConversationService

    init(chatHistoryService: ChatHistoryService, conversationService: ConversationService) {
        self.chatHistoryService = chatHistoryService
        self.conversationService = conversationService
    }

    // MARK: - HistoryQueryService

    func fetchMessageCount() async -> Int {
        let context = chatHistoryService.getContext()
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { message in
                message.conversation != nil
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow] {
        guard limit > 0, offset >= 0 else { return [] }

        let context = chatHistoryService.getContext()

        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { message in
                message.conversation != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        guard let entities = try? context.fetch(descriptor) else { return [] }

        return entities.compactMap { entity -> HistoryMessageRow? in
            guard !entity.isDeleted,
                  let conversationId = entity.conversation?.id else { return nil }

            return HistoryMessageRow(
                id: entity.id,
                conversationId: conversationId,
                conversationTitle: entity.conversation?.title ?? "",
                role: entity._role,
                model: entity.modelName ?? "",
                tokens: entity.metrics?.totalTokens ?? 0,
                timestamp: entity.timestamp,
                contentPreview: String(entity.content.prefix(200))
            )
        }
    }

    func fetchConversationCount() async -> Int {
        conversationService.fetchConversationCount()
    }

    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow] {
        let conversations = conversationService.fetchConversationsPage(
            limit: limit,
            offset: offset
        )

        return conversations.map { conv in
            // 获取该对话的消息数
            let context = chatHistoryService.getContext()
            let convId = conv.id
            let countDescriptor = FetchDescriptor<ChatMessageEntity>(
                predicate: #Predicate<ChatMessageEntity> { msg in
                    msg.conversation?.id == convId
                }
            )
            let messageCount = (try? context.fetchCount(countDescriptor)) ?? 0

            return HistoryConversationRow(
                id: conv.id,
                title: conv.title,
                projectId: conv.projectId ?? "-",
                createdAt: conv.createdAt,
                updatedAt: conv.updatedAt,
                messageCount: messageCount,
                providerId: conv.providerId,
                model: conv.model,
                chatMode: conv.chatMode
            )
        }
    }
}
