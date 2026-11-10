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
        // 缓存数组外的会话（窗口外旧会话/整表重载）也要保留刚选中的模型；
        // 否则 selectModel 的 guard 会让选择静默消失。
        return modelIDOverrides[conversationID]
            ?? conversations.first { $0.id == conversationID }?.modelID
    }

    public func selectModel(id: String, for conversationID: UUID?) {
        guard let conversationID, LLMModelID(rawValue: id) != nil else { return }
        modelIDOverrides[conversationID] = id
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].modelID = id
        }
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
        // New Chat 的默认详细度没有会话承载，必须单独落盘才能跨重启保留。
        persistSelectedConversationID()

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
    ///
    /// 缓存外的会话（分页加载的历史会话）也要返回 ID，否则设置会静默丢失；
    /// 内存只在命中时同步，写盘始终以会话 ID 为准。
    private func applyVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) -> UUID? {
        guard let conversationID else {
            return nil
        }
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].verbosity = verbosity
        }
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
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].reasoningEffort = reasoningEffort
        }
        reasoningEffortOverrides[conversationID] = reasoningEffort
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
        // 缓存未命中不等于「未设置」：后台会话被挤出有界窗口后，下一请求
        // 仍须使用它自己的推理强度，否则出站请求会静默省略 reasoning_effort
        // （issue #892）。
        return conversations.first { $0.id == conversationID }?.reasoningEffort
            ?? reasoningEffortOverrides[conversationID]
    }

    public func clearReasoningEffort(for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].reasoningEffort = nil
        }
        // 显式清除必须同时丢弃淘汰前的快照，否则会话在缓存外仍会读回旧档位。
        reasoningEffortOverrides[conversationID] = nil
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
        // 缓存未命中不等于 Build：后台会话被挤出有界窗口后，仍须使用它自己的
        // 自动化级别，否则同一后台回合的工具可用性与授权策略会静默改变（issue #1008）。
        return conversations.first { $0.id == conversationID }?.automationLevel
            ?? automationLevelOverrides[conversationID]
            ?? .build
    }

    public func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].automationLevel = automationLevel
        }
        automationLevelOverrides[conversationID] = automationLevel
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
        // 缓存外的会话（被挤出窗口的后台会话）必须回落到它自己的语言，
        // 不能借用与它无关的 New Chat 全局默认值（issue #984）。
        return languageOverrides[conversationID]
            ?? conversations.first { $0.id == conversationID }?.language
            ?? globalLanguage
    }

    public func setGlobalLanguage(_ language: ConversationLanguage) {
        guard globalLanguage != language else { return }
        globalLanguage = language
        notifyConversationObservers(.languageChanged(nil))
        // New Chat 的默认语言没有会话承载，必须单独落盘才能跨重启保留。
        persistSelectedConversationID()

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalLanguage: language=\(language.rawValue)")
        }
    }

    public func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        languageOverrides[conversationID] = language
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].language = language
        }
        notifyConversationObservers(.languageChanged(conversationID))

        if Self.verbose {
            Self.logger.info("\(Self.t)setLanguage: conversation=\(conversationID.uuidString.prefix(8)), language=\(language.rawValue)")
        }
    }
}
