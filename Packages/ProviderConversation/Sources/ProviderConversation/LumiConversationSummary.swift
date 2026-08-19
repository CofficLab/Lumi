import Foundation

/// 对话摘要：对话列表 / 侧边栏等轻量 UI 使用的数据模型。
public struct LumiConversationSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String?
    public var preview: String
    public var createdAt: Date
    public var updatedAt: Date
    /// Timestamp of the last message received (used for conversation list sorting)
    public var lastMessageAt: Date
    public var verbosity: LumiResponseVerbosity?
    public var reasoningEffort: LumiReasoningEffort?
    public var language: LumiConversationLanguage?
    public var automationLevel: LumiAutomationLevel?
    public var providerID: String?
    public var modelName: String?
    public var projectPath: String?
    /// The conversation that spawned this conversation, if it was created by a sub-agent.
    public var parentConversationID: UUID?

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date? = nil,
        verbosity: LumiResponseVerbosity? = nil,
        reasoningEffort: LumiReasoningEffort? = nil,
        language: LumiConversationLanguage? = nil,
        automationLevel: LumiAutomationLevel? = nil,
        providerID: String? = nil,
        modelName: String? = nil,
        projectPath: String? = nil,
        parentConversationID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt ?? createdAt
        self.verbosity = verbosity
        self.reasoningEffort = reasoningEffort
        self.language = language
        self.automationLevel = automationLevel
        self.providerID = providerID
        self.modelName = modelName
        self.projectPath = projectPath
        self.parentConversationID = parentConversationID
    }

    public var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    public var hasCustomTitle: Bool {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
}
