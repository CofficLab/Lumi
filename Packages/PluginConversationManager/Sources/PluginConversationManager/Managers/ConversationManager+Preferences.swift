import Foundation
import ProviderConversation

extension ConversationManager {
    // MARK: - Provider/Model Selection

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.modelName
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].providerID = id
        conversations[index].modelName = model

        // Persist to database async
        Task {
            await store?.updateConversationProvider(id: conversationID, providerID: id, modelName: model)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)selectProvider: conversation=\(conversationID.uuidString.prefix(8)), provider=\(id), model=\(model ?? "nil")")
        }
    }

    // MARK: - Verbosity

    public func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) {
        globalVerbosity = verbosity

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalVerbosity: verbosity=\(verbosity.rawValue)")
        }
    }

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID else {
            return .defaultVerbosity
        }
        return conversations.first { $0.id == conversationID }?.verbosity ?? .defaultVerbosity
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].verbosity = verbosity
        // 重新赋值触发 @Published，并广播变更通知，使依赖该会话 verbosity 的视图
        // （消息列表、工具栏等）即时刷新：消息列表会据此重新加载（工具消息的显隐）
        // 并注入新的 verbosity 环境值。
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, verbosity: verbosity)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setVerbosity: conversation=\(conversationID.uuidString.prefix(8)), verbosity=\(verbosity.rawValue)")
        }
    }

    // MARK: - Reasoning Effort

    public func setGlobalReasoningEffort(_ reasoningEffort: LumiReasoningEffort?) {
        globalReasoningEffort = reasoningEffort

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalReasoningEffort: effort=\(reasoningEffort?.rawValue ?? "off")")
        }
    }

    public func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort {
        guard let conversationID else {
            return .defaultEffort
        }
        return conversations.first { $0.id == conversationID }?.reasoningEffort ?? .defaultEffort
    }

    public func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].reasoningEffort = reasoningEffort
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, reasoningEffort: reasoningEffort)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setReasoningEffort: conversation=\(conversationID.uuidString.prefix(8)), effort=\(reasoningEffort.rawValue)")
        }
    }

    public func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.reasoningEffort
    }

    public func clearReasoningEffort(for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].reasoningEffort = nil
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, setReasoningEffortToNil: true)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)clearReasoningEffort: conversation=\(conversationID.uuidString.prefix(8))")
        }
    }

    // MARK: - Automation Level

    public func setGlobalAutomationLevel(_ automationLevel: LumiAutomationLevel) {
        globalAutomationLevel = automationLevel

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalAutomationLevel: level=\(automationLevel.rawValue)")
        }
    }

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID else {
            return .build
        }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? .build
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].automationLevel = automationLevel
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, automationLevel: automationLevel)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setAutomationLevel: conversation=\(conversationID.uuidString.prefix(8)), level=\(automationLevel.rawValue)")
        }
    }

    // MARK: - Language

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID else {
            return globalLanguage
        }
        return conversations.first { $0.id == conversationID }?.language ?? globalLanguage
    }

    public func setGlobalLanguage(_ language: LumiConversationLanguage) {
        globalLanguage = language

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalLanguage: language=\(language.rawValue)")
        }
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].language = language

        if Self.verbose {
            Self.logger.info("\(Self.t)setLanguage: conversation=\(conversationID.uuidString.prefix(8)), language=\(language.rawValue)")
        }
    }
}
