import Foundation
import SwiftData
import OSLog

/// 聊天历史服务 - 使用 SwiftData 存储对话
@MainActor
class ChatHistoryService {
    static let shared = ChatHistoryService()
    
    private var modelContainer: ModelContainer?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cofficlab.lumi", category: "ChatHistory")
    
    private init() {}
    
    /// 使用外部容器初始化（从 App 初始化）
    func initializeWithContainer(_ container: ModelContainer) {
        self.modelContainer = container
        logger.info("✅ SwiftData 聊天存储已初始化")
    }
    
    // MARK: - 保存对话
    
    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return
        }
        
        let context = ModelContext(container)
        context.insert(conversation)
        
        do {
            try context.save()
            logger.info("💾 对话已保存：\(conversation.title)")
        } catch {
            logger.error("❌ 保存对话失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 创建对话
    
    /// 创建新对话
    func createConversation(projectId: String? = nil, title: String = "新对话") -> Conversation {
        let conversation = Conversation(
            projectId: projectId,
            title: title,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        saveConversation(conversation)
        
        return conversation
    }
    
    // MARK: - 保存消息
    
    /// 保存消息到指定对话
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return
        }
        
        let context = ModelContext(container)
        
        // 创建消息实体
        let messageEntity = ChatMessageEntity.fromChatMessage(message)
        messageEntity.conversation = conversation
        
        context.insert(messageEntity)
        conversation.updatedAt = Date()
        
        do {
            try context.save()
            logger.debug("💾 消息已保存")
        } catch {
            logger.error("❌ 保存消息失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 加载对话
    
    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return []
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            let conversations = try context.fetch(descriptor)
            logger.info("📄 获取到 \(conversations.count) 个对话")
            return conversations
        } catch {
            logger.error("❌ 获取对话失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return nil
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let conversations = try context.fetch(descriptor)
            return conversations.first
        } catch {
            logger.error("❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取项目相关的对话
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return []
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            let conversations = try context.fetch(descriptor)
            logger.info("📄 获取到项目 \(projectId) 的 \(conversations.count) 个对话")
            return conversations
        } catch {
            logger.error("❌ 获取项目对话失败：\(error.localizedDescription)")
            return []
        }
    }
    
    /// 加载对话的消息
    func loadMessages(for conversation: Conversation) -> [ChatMessage] {
        // 获取关联的消息
        let messages = conversation.messages
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { $0.toChatMessage() }
        
        logger.debug("📄 加载到 \(messages.count) 条消息")
        return messages
    }
    
    // MARK: - 删除对话
    
    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        guard let container = modelContainer else {
            logger.error("❌ 模型容器未初始化")
            return
        }
        
        let context = ModelContext(container)
        context.delete(conversation)
        
        do {
            try context.save()
            logger.info("🗑️ 对话已删除：\(conversation.title)")
        } catch {
            logger.error("❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
    
    // MARK: - 工具方法
    
    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer? {
        return modelContainer
    }
}
