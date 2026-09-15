import Foundation
import KitLLM
import ProviderConversation

extension ConversationManager {
    // MARK: - Provider/Model Selection

    public func providerID(for conversationID: UUID?) -> String? {
        guard let modelID = modelID(for: conversationID) else { return nil }
        return LLMModelID(rawValue: modelID)?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let modelID = modelID(for: conversationID) else { return nil }
        return LLMModelID(rawValue: modelID)?.modelID
    }

    public func modelID(for conversationID: UUID?) -> String? {
        guard let conversationID else { return nil }
        return conversations.first { $0.id == conversationID }?.modelID
    }

    public func selectModel(id: String, for conversationID: UUID?) {
        guard let conversationID,
              let index = conversations.firstIndex(where: { $0.id == conversationID }),
              LLMModelID(rawValue: id) != nil else { return }
        conversations[index].modelID = id
        notifyConversationObservers(.providerChanged(conversationID))

        Task {
            await store?.updateConversationModelID(id, for: conversationID)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)selectModel: conversation=\(conversationID.uuidString.prefix(8)), modelID=\(id)")
        }
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let resolved = llmProviderManager?.modelID(providerID: id, model: model)
            ?? model.flatMap({ LLMModelID(providerID: id, modelID: $0) }) else { return }
        selectModel(id: resolved.rawValue, for: conversationID)
    }

    // MARK: - Verbosity

    public func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        guard globalVerbosity != verbosity else { return }
        globalVerbosity = verbosity
        notifyConversationObservers(.verbosityChanged(nil))

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalVerbosity: verbosity=\(verbosity.rawValue)")
        }
    }

    public func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        guard let conversationID else {
            return .defaultVerbosity
        }
        return conversations.first { $0.id == conversationID }?.verbosity ?? .defaultVerbosity
    }

    public func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID = applyVerbosity(verbosity, for: conversationID) else { return }
        Task { await store?.updateConversationPreferences(id: conversationID, verbosity: verbosity) }

        if Self.verbose {
            Self.logger.info("\(Self.t)setVerbosity: conversation=\(conversationID.uuidString.prefix(8)), verbosity=\(verbosity.rawValue)")
        }
    }

    /// 设置详细程度并等待数据库写入完成，供需要在退出前确认保存结果的调用方使用。
    public func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async {
        guard let conversationID = applyVerbosity(verbosity, for: conversationID) else { return }
        _ = await store?.updateConversationPreferences(id: conversationID, verbosity: verbosity)

        if Self.verbose {
            Self.logger.info("\(Self.t)setVerbosityAndWait: conversation=\(conversationID.uuidString.prefix(8)), verbosity=\(verbosity.rawValue)")
        }
    }

    /// 先更新内存并通知 UI，再由调用方决定是否等待持久化。
    private func applyVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) -> UUID? {
        guard let conversationID,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return nil
        }
        conversations[index].verbosity = verbosity
        notifyConversationObservers(.verbosityChanged(conversationID))
        return conversationID
    }

    // MARK: - Reasoning Effort

    public func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {
        guard globalReasoningEffort != reasoningEffort else { return }
        globalReasoningEffort = reasoningEffort
        notifyConversationObservers(.reasoningChanged(nil))

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalReasoningEffort: effort=\(reasoningEffort?.rawValue ?? "off")")
        }
    }

    public func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort {
        guard let conversationID else {
            return .defaultEffort
        }
        return conversations.first { $0.id == conversationID }?.reasoningEffort ?? .defaultEffort
    }

    public func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].reasoningEffort = reasoningEffort
        notifyConversationObservers(.reasoningChanged(conversationID))
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, reasoningEffort: reasoningEffort)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setReasoningEffort: conversation=\(conversationID.uuidString.prefix(8)), effort=\(reasoningEffort.rawValue)")
        }
    }

    public func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? {
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
        notifyConversationObservers(.reasoningChanged(conversationID))
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, setReasoningEffortToNil: true)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)clearReasoningEffort: conversation=\(conversationID.uuidString.prefix(8))")
        }
    }

    // MARK: - Automation Level

    public func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {
        guard globalAutomationLevel != automationLevel else { return }
        globalAutomationLevel = automationLevel
        notifyConversationObservers(.automationChanged(nil))

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalAutomationLevel: level=\(automationLevel.rawValue)")
        }
    }

    public func automationLevel(for conversationID: UUID?) -> AutomationLevel {
        guard let conversationID else {
            return .build
        }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? .build
    }

    public func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].automationLevel = automationLevel
        notifyConversationObservers(.automationChanged(conversationID))

        Task {
            await store?.updateConversationPreferences(id: conversationID, automationLevel: automationLevel)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setAutomationLevel: conversation=\(conversationID.uuidString.prefix(8)), level=\(automationLevel.rawValue)")
        }
    }

    // MARK: - Language

    public func language(for conversationID: UUID?) -> ConversationLanguage {
        guard let conversationID else {
            return globalLanguage
        }
        return conversations.first { $0.id == conversationID }?.language ?? globalLanguage
    }

    public func setGlobalLanguage(_ language: ConversationLanguage) {
        guard globalLanguage != language else { return }
        globalLanguage = language
        notifyConversationObservers(.languageChanged(nil))

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalLanguage: language=\(language.rawValue)")
        }
    }

    public func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].language = language
        notifyConversationObservers(.languageChanged(conversationID))

        if Self.verbose {
            Self.logger.info("\(Self.t)setLanguage: conversation=\(conversationID.uuidString.prefix(8)), language=\(language.rawValue)")
        }
    }
}
