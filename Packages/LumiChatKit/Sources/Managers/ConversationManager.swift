import Foundation
import LumiCoreKit

/// Manages conversation lifecycle and preferences.
@MainActor
final class ConversationManager {
    private weak var service: ChatService?

    init(service: ChatService) {
        self.service = service
    }

    // MARK: - Conversation CRUD

    @discardableResult
    func createConversation(
        title: String?,
        projectPath: String?,
        language: LumiConversationLanguage?
    ) -> UUID {
        guard let service else { return UUID() }

        let now = Date()
        let resolvedProjectPath = Self.normalizedOptionalPath(projectPath)
            ?? Self.normalizedOptionalPath(service.lumiCore?.projectComponent.currentProject?.path)

        let conversation = LumiConversationSummary(
            title: service.normalizedTitle(title) ?? "New Chat",
            createdAt: now,
            updatedAt: now,
            verbosity: service.verbosity(for: service.selectedConversationID),
            language: language ?? service.language(for: service.selectedConversationID),
            automationLevel: service.automationLevel(for: service.selectedConversationID),
            providerID: service.selectedProviderID,
            modelName: service.selectedModel,
            projectPath: resolvedProjectPath
        )

        // 合并 @Published 通知：在修改前手动发一次通知，
        // 让 SwiftUI 只在这批变更完成后重绘一次。
        service.objectWillChange.send()
        service.conversations.insert(conversation, at: 0)
        service.messagesByConversationID[conversation.id] = []
        service.selectedConversationID = conversation.id
        // 增量持久化：只插入新对话 + 保存状态 + 合并 revision
        service.persistConversationAndStateMerged(conversation)
        return conversation.id
    }

    func selectConversation(id: UUID) {
        guard let service,
              service.conversations.contains(where: { $0.id == id })
        else {
            return
        }

        service.selectedConversationID = id
        // 只保存状态（selectedConversationID），不扫描对话和消息
        service.persistStateOnly()
    }

    func conversationSummary(for id: UUID) -> LumiConversationSummary? {
        service?.conversations.first(where: { $0.id == id })
    }

    func deleteConversation(id: UUID) {
        guard let service else { return }

        service.cancelSending(for: id)
        service.pendingMessages.removeAll { $0.conversationID == id }
        service.conversations.removeAll { $0.id == id }
        service.messagesByConversationID[id] = nil
        service.statusState.clearStatus(conversationID: id)

        if service.selectedConversationID == id {
            service.selectedConversationID = service.conversations.first?.id
        }

        // 增量删除：只删除该对话及其消息，不全量扫描
        service.persistDeleteConversation(id: id)
    }

    @discardableResult
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let service,
              let index = service.conversations.firstIndex(where: { $0.id == conversationID }),
              let trimmed = service.normalizedTitle(title)
        else {
            return false
        }

        service.conversations[index].title = trimmed
        service.conversations[index].updatedAt = Date()
        service.persistConversationAndState(service.conversations[index])
        return true
    }

    @discardableResult
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool {
        guard let service,
              let index = service.conversations.firstIndex(where: { $0.id == conversationID })
        else {
            return false
        }

        service.conversations[index].projectPath = Self.normalizedOptionalPath(projectPath)
        service.conversations[index].updatedAt = Date()
        service.persistConversationAndState(service.conversations[index])
        return true
    }

    // MARK: - Language

    func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID,
              let conversation = service?.conversations.first(where: { $0.id == conversationID })
        else {
            return .chinese
        }
        return conversation.language ?? .chinese
    }

    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        guard let service else { return }
        let targetID = conversationID ?? service.selectedConversationID ?? createConversation(title: nil, projectPath: nil, language: nil)
        guard let index = service.conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        service.conversations[index].language = language
        service.conversations[index].updatedAt = Date()
        service.persistConversationAndState(service.conversations[index])
    }

    // MARK: - Automation Level

    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID,
              let conversation = service?.conversations.first(where: { $0.id == conversationID })
        else {
            return .autonomous
        }
        return conversation.automationLevel ?? .autonomous
    }

    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        guard let service else { return }
        let targetID = conversationID ?? service.selectedConversationID ?? createConversation(title: nil, projectPath: nil, language: nil)
        guard let index = service.conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        service.conversations[index].automationLevel = automationLevel
        service.conversations[index].updatedAt = Date()
        service.persistConversationAndState(service.conversations[index])
    }

    // MARK: - Verbosity

    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID,
              let conversation = service?.conversations.first(where: { $0.id == conversationID })
        else {
            return .detailed
        }
        return conversation.verbosity ?? .detailed
    }

    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        guard let service else { return }
        let targetID = conversationID ?? service.selectedConversationID ?? createConversation(title: nil, projectPath: nil, language: nil)
        guard let index = service.conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        service.conversations[index].verbosity = verbosity
        service.conversations[index].updatedAt = Date()
        service.persistConversationAndState(service.conversations[index])
    }

    // MARK: - Title helper

    func title(from text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 28 {
            return trimmed.isEmpty ? "New Chat" : trimmed
        }
        return "\(trimmed.prefix(28))..."
    }

    // MARK: - Normalization

    private static func normalizedOptionalPath(_ path: String?) -> String? {
        guard let path else {
            return nil
        }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
