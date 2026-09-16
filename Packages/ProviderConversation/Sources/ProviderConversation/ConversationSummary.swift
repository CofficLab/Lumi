import Foundation
import KitLLM

/// 对话摘要：对话列表 / 侧边栏等轻量 UI 使用的数据模型。
public struct ConversationSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String?
    public var preview: String
    public var createdAt: Date
    public var updatedAt: Date
    /// Timestamp of the last message received (used for conversation list sorting)
    public var lastMessageAt: Date
    public var verbosity: ResponseVerbosity?
    public var reasoningEffort: ReasoningEffort?
    public var language: ConversationLanguage?
    public var automationLevel: AutomationLevel?
    /// Lumi 全局唯一的模型选择 ID。供应商和 API 模型名由 ID 解出。
    public var modelID: String?
    /// 兼容旧消费者的派生字段，不单独存储。
    public var providerID: String? { modelIdentifier?.providerID }
    /// 兼容旧消费者的派生字段，不单独存储。
    public var modelName: String? { modelIdentifier?.modelID }
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
        verbosity: ResponseVerbosity? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        language: ConversationLanguage? = nil,
        automationLevel: AutomationLevel? = nil,
        modelID: String? = nil,
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
        self.modelID = modelID.flatMap { LLMModelID(rawValue: $0)?.rawValue } ?? providerID.flatMap { provider in
            modelName.flatMap { LLMModelID(providerID: provider, modelID: $0)?.rawValue }
        }
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

    private var modelIdentifier: LLMModelID? {
        modelID.flatMap(LLMModelID.init(rawValue:))
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, preview, createdAt, updatedAt, lastMessageAt
        case verbosity, reasoningEffort, language, automationLevel
        case modelID, providerID, modelName, projectPath, parentConversationID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt) ?? updatedAt
        verbosity = try container.decodeIfPresent(ResponseVerbosity.self, forKey: .verbosity)
        reasoningEffort = try container.decodeIfPresent(ReasoningEffort.self, forKey: .reasoningEffort)
        language = try container.decodeIfPresent(ConversationLanguage.self, forKey: .language)
        automationLevel = try container.decodeIfPresent(AutomationLevel.self, forKey: .automationLevel)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        parentConversationID = try container.decodeIfPresent(UUID.self, forKey: .parentConversationID)

        if let modelID = try container.decodeIfPresent(String.self, forKey: .modelID),
           LLMModelID(rawValue: modelID) != nil {
            self.modelID = modelID
        } else if let providerID = try container.decodeIfPresent(String.self, forKey: .providerID),
                  let modelName = try container.decodeIfPresent(String.self, forKey: .modelName) {
            self.modelID = LLMModelID(providerID: providerID, modelID: modelName)?.rawValue
        } else {
            modelID = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(preview, forKey: .preview)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(lastMessageAt, forKey: .lastMessageAt)
        try container.encodeIfPresent(verbosity, forKey: .verbosity)
        try container.encodeIfPresent(reasoningEffort, forKey: .reasoningEffort)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(automationLevel, forKey: .automationLevel)
        try container.encodeIfPresent(modelID, forKey: .modelID)
        try container.encodeIfPresent(projectPath, forKey: .projectPath)
        try container.encodeIfPresent(parentConversationID, forKey: .parentConversationID)
    }
}
