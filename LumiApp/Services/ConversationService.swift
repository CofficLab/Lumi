import Foundation
import SwiftData
import LumiCoreKit

// MARK: - 通知常量

extension Notification.Name {
    static let conversationDidChange = Notification.Name("ConversationService.ConversationDidChange")
}

enum ConversationChangeType: String {
    case created
    case updated
    case deleted
}

enum ConversationChangeUserInfoKey {
    static let type = "type"
    static let conversationId = "conversationId"
}

enum ConversationCreationError: LocalizedError {
    case missingProvider
    case missingModel
    case missingProviderAndModel

    var errorDescription: String? {
        switch self {
        case .missingProvider:
            return "创建对话必须指定供应商"
        case .missingModel:
            return "创建对话必须指定大模型"
        case .missingProviderAndModel:
            return "创建对话必须指定供应商和大模型，请先在模型选择器中选择"
        }
    }
}

/// 对话持久化服务 — 唯一负责 SwiftData 中 `Conversation` 实体的读写。
///
/// ## 线程安全
///
/// 整个服务标记为 `@MainActor`，所有数据库操作都在主线程执行。
@MainActor
final class ConversationService: SuperLog, Sendable {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    private struct ModelPreferenceKey: Hashable {
        let providerId: String
        let model: String
    }

    init(modelContainer: ModelContainer, reason: String) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 对话存储已初始化")
        }
    }

    func getContext() -> ModelContext {
        modelContext
    }

    func getModelContainer() -> ModelContainer {
        modelContainer
    }
}

// MARK: - 对话创建

extension ConversationService {

    /// 创建新对话
    func createConversation(
        providerId: String,
        model: String,
        projectId: String? = nil,
        title: String = "",
        chatMode: String? = nil,
        languagePreference: String? = nil
    ) throws -> Conversation {
        let trimmedProviderId = providerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProviderId.isEmpty else { throw ConversationCreationError.missingProvider }
        guard !trimmedModel.isEmpty else { throw ConversationCreationError.missingModel }

        let conversation = Conversation(
            projectId: projectId,
            title: title,
            createdAt: Date(),
            updatedAt: Date(),
            chatMode: chatMode,
            languagePreference: languagePreference
        )
        conversation.providerId = trimmedProviderId
        conversation.model = trimmedModel

        saveConversation(conversation)
        notifyConversationChanged(type: .created, conversationId: conversation.id)
        NotificationCenter.postConversationCreated(conversationId: conversation.id)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✨ 创建新对话：\(title)")
        }

        return conversation
    }
}

// MARK: - 对话查询

extension ConversationService {

    func fetchConversationCount() -> Int {
        let descriptor = FetchDescriptor<Conversation>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// 获取所有对话（按更新时间倒序）
    func fetchAllConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let conversations = try modelContext.fetch(descriptor)
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
    func fetchConversationsPage(limit: Int, offset: Int, projectId: String? = nil) -> [Conversation] {
        guard limit > 0, offset >= 0 else { return [] }

        var descriptor: FetchDescriptor<Conversation>
        if let projectId {
            descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.projectId == projectId },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.core.error("\(Self.t)❌ 分页获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 获取指定项目最近更新的一个对话
    func fetchLatestConversation(projectId: String) -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取项目最新对话失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 获取最流行的供应商和模型（基于对话历史分析）
    func fetchMostPopularModelPreference() -> (providerId: String, model: String)? {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.providerId != nil && $0.model != nil },
            sortBy: []
        )

        guard let conversations = try? modelContext.fetch(descriptor), !conversations.isEmpty else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 无对话记录设置模型偏好")
            }
            return nil
        }

        var usageCount: [ModelPreferenceKey: Int] = [:]
        for conversation in conversations {
            guard let providerId = conversation.providerId,
                  let model = conversation.model else {
                continue
            }
            let key = ModelPreferenceKey(providerId: providerId, model: model)
            usageCount[key] = (usageCount[key] ?? 0) + 1
        }

        guard let topKey = usageCount.max(by: { $0.value < $1.value })?.key else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 无法确定最流行的模型偏好")
            }
            return nil
        }

        let result = (providerId: topKey.providerId, model: topKey.model)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📊 最流行模型偏好：\(result.providerId) - \(result.model)（使用 \(usageCount[topKey] ?? 0) 次）")
        }

        return result
    }

    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 对话更新

extension ConversationService {

    /// 消息保存前刷新会话 `updatedAt`（由 MessageService 在同一 context.save 中一并持久化）。
    func touchUpdatedAt(forConversationId conversationId: UUID) {
        guard let conversation = fetchConversation(id: conversationId) else { return }
        conversation.updatedAt = Date()
    }

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

    /// 更新对话的供应商/模型偏好
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

    /// 更新对话的响应详细程度偏好
    func updateVerbosity(_ conversation: Conversation, verbosity: String?) {
        conversation.verbosity = verbosity
        conversation.updatedAt = Date()
        saveConversation(conversation)

        if Self.verbose {
            if let verbosity {
                AppLogger.core.info("\(Self.t)📝 已保存对话 '\(conversation.title)' 的详细程度：\(verbosity)")
            } else {
                AppLogger.core.info("\(Self.t)📝 已清除对话 '\(conversation.title)' 的详细程度")
            }
        }
    }

    /// 更新对话的语言偏好
    func updateLanguagePreference(_ conversation: Conversation, languagePreference: String?) {
        conversation.languagePreference = languagePreference
        conversation.updatedAt = Date()
        saveConversation(conversation)

        if Self.verbose {
            if let languagePreference {
                AppLogger.core.info("\(Self.t)🌐 已保存对话 '\(conversation.title)' 的语言偏好：\(languagePreference)")
            } else {
                AppLogger.core.info("\(Self.t)🌐 已清除对话 '\(conversation.title)' 的语言偏好")
            }
        }
    }

    /// 更新对话关联的项目
    func updateProjectAssociation(_ conversation: Conversation, projectPath: String?) {
        conversation.projectId = projectPath
        conversation.updatedAt = Date()

        saveConversation(conversation)
        notifyConversationChanged(type: .updated, conversationId: conversation.id)
        NotificationCenter.postConversationUpdated(conversationId: conversation.id)

        if Self.verbose {
            if let projectPath {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                AppLogger.core.info("\(Self.t)📁 已将对话 '\(conversation.title)' 关联到项目：\(projectName)")
            } else {
                AppLogger.core.info("\(Self.t)📁 已清除对话 '\(conversation.title)' 的项目关联")
            }
        }
    }
}

// MARK: - 对话存储与删除

extension ConversationService {

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        modelContext.insert(conversation)

        do {
            try modelContext.save()
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

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

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)

        do {
            try modelContext.save()
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

// MARK: - Agent Turn Phase

extension ConversationService {

    func loadTurnPhase(forConversationId conversationId: UUID) -> AgentTurnPhase {
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        descriptor.fetchLimit = 1
        guard let conversation = try? modelContext.fetch(descriptor).first else {
            return .idle
        }
        return AgentTurnPhase(storedValue: conversation.turnPhase)
    }

    func setTurnPhase(_ phase: AgentTurnPhase, forConversationId conversationId: UUID) {
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        descriptor.fetchLimit = 1
        guard let conversation = try? modelContext.fetch(descriptor).first else { return }

        conversation.turnPhase = phase == .idle ? nil : phase.rawValue
        conversation.updatedAt = Date()
        try? modelContext.save()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)↔️ [Phase] → \(phase.rawValue)")
        }
        NotificationCenter.default.post(
            name: .agentTurnPhaseChanged,
            object: conversationId,
            userInfo: ["phase": phase.rawValue]
        )
    }
}
