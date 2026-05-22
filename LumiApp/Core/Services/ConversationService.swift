import Foundation
import SwiftData
import LLMKit

/// 对话服务
///
/// 专用于操作 `Conversation` 表（CRUD、分页查询、偏好设置等）。
/// 不涉及消息操作——消息的保存、加载、分页由 `ChatHistoryService` 负责。
///
/// ## 设计原则
///
/// - **职责单一**：只操作 `Conversation` 表，不碰 `ChatMessageEntity`
/// - **线程安全**：标记为 `@MainActor`，所有数据库操作在主线程执行
/// - **事件通知**：变更后通过 `NotificationCenter` 广播，保持与现有代码的兼容
@MainActor
final class ConversationService: SuperLog, Sendable {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    /// LLM 服务（仅用于自动生成对话标题）
    private let llmService: LLMService

    init(llmService: LLMService, modelContainer: ModelContainer, reason: String) {
        self.llmService = llmService
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 对话服务已初始化")
        }
    }

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }

    // MARK: - Internal

    private func getContext() -> ModelContext {
        return modelContext
    }
}

// MARK: - 创建

extension ConversationService {

    /// 创建新对话
    ///
    /// - Parameters:
    ///   - projectId: 关联的项目路径，nil 表示全局对话
    ///   - title: 对话标题
    ///   - chatMode: 聊天模式 rawValue
    /// - Returns: 创建后的对话对象
    @discardableResult
    func createConversation(
        projectId: String? = nil,
        title: String = "新对话",
        chatMode: String? = nil
    ) -> Conversation {
        let conversation = Conversation(
            projectId: projectId,
            title: title,
            createdAt: Date(),
            updatedAt: Date(),
            chatMode: chatMode
        )

        saveConversation(conversation)
        notifyConversationChanged(type: .created, conversationId: conversation.id)
        NotificationCenter.postConversationCreated(conversationId: conversation.id)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✨ 创建新对话：\(title)")
        }

        return conversation
    }
}

// MARK: - 查询

extension ConversationService {

    /// 获取所有对话（按创建时间倒序）
    func fetchAllConversations() -> [Conversation] {
        let context = getContext()
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let conversations = try context.fetch(descriptor)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📄 获取到 \(conversations.count) 个对话")
            }
            return conversations
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 分页获取对话
    ///
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    ///   - projectId: 可选项目 ID；为 nil 时拉取全部对话
    /// - Returns: 当前页对话数据
    func fetchConversationsPage(
        limit: Int,
        offset: Int,
        projectId: String? = nil
    ) -> [Conversation] {
        let context = getContext()

        guard limit > 0, offset >= 0 else { return [] }

        var descriptor: FetchDescriptor<Conversation>
        if let projectId {
            descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.projectId == projectId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.core.error("\(Self.t)❌ 分页获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 获取指定项目最近更新的一个对话
    ///
    /// - Parameter projectId: 项目路径
    /// - Returns: 该项目最近使用的对话，不存在时返回 nil
    func fetchLatestConversation(projectId: String) -> Conversation? {
        let context = getContext()
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取项目最新对话失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        let context = getContext()
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 更新

extension ConversationService {

    /// 更新对话标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        conversation.title = newTitle
        conversation.updatedAt = Date()

        saveConversation(conversation)
        notifyConversationChanged(type: .updated, conversationId: conversation.id)
        NotificationCenter.postConversationUpdated(conversationId: conversation.id)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    /// 基于用户消息自动生成会话标题
    ///
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    /// - Returns: 生成的标题（最多 20 个字符）
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await ConversationTitleGenerator().generate(userMessage: userMessage, config: config) { [llmService] messages, config in
            try await llmService.sendMessage(messages: messages, config: config, tools: [])
        }
    }

    /// 更新对话的供应商/模型偏好
    ///
    /// - Parameters:
    ///   - conversation: 目标对话
    ///   - providerId: 供应商 ID，nil 表示清除对话级偏好（回退到项目偏好）
    ///   - model: 模型名称，nil 表示清除对话级偏好（回退到项目偏好）
    func updateModelPreference(_ conversation: Conversation, providerId: String?, model: String?) {
        conversation.providerId = providerId
        conversation.model = model
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            if let providerId, let model {
                AppLogger.core.info("\(Self.t)🎯 已保存对话 '\(conversation.title)' 的模型偏好：\(providerId) - \(model)")
            } else {
                AppLogger.core.info("\(Self.t)🎯 已清除对话 '\(conversation.title)' 的模型偏好")
            }
        }
    }

    /// 更新对话的聊天模式偏好
    ///
    /// - Parameters:
    ///   - conversation: 目标对话
    ///   - chatMode: 聊天模式 rawValue，nil 表示清除对话级偏好（回退到全局偏好）
    func updateChatMode(_ conversation: Conversation, chatMode: String?) {
        conversation.chatMode = chatMode
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            if let chatMode {
                AppLogger.core.info("\(Self.t)🔄 已保存对话 '\(conversation.title)' 的聊天模式：\(chatMode)")
            } else {
                AppLogger.core.info("\(Self.t)🔄 已清除对话 '\(conversation.title)' 的聊天模式")
            }
        }
    }
}

// MARK: - 删除

extension ConversationService {

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        let context = getContext()
        context.delete(conversation)

        do {
            try context.save()
            notifyConversationChanged(type: .deleted, conversationId: conversation.id)
            NotificationCenter.postConversationDeleted(conversationId: conversation.id)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 对话已删除：\(conversation.title)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 存储 & 通知

extension ConversationService {

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        let context = getContext()
        context.insert(conversation)

        do {
            try context.save()
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

    /// 广播对话变更通知
    func notifyConversationChanged(type: ConversationChangeType, conversationId: UUID) {
        let userInfo: [String: String] = [
            ConversationChangeUserInfoKey.type: type.rawValue,
            ConversationChangeUserInfoKey.conversationId: conversationId.uuidString,
        ]

        let postOnCurrentThread = {
            NotificationCenter.default.post(
                name: .conversationDidChange,
                object: nil,
                userInfo: userInfo
            )
        }

        if Thread.isMainThread {
            postOnCurrentThread()
        } else {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .conversationDidChange,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }
}
