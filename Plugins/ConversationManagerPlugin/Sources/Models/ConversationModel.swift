import Foundation
import SwiftData
import LumiKernel

/// SwiftData model for conversations
///
/// Stored in plugin专属 SQLite database, managed by `ConversationStore`.
@Model
final public class ConversationModel: @unchecked Sendable {
    /// Unique identifier (UUID)
    public var id: String

    /// Conversation title
    public var title: String

    /// Preview text (last message preview)
    public var preview: String

    /// Creation timestamp
    public var createdAt: TimeInterval

    /// Last update timestamp
    public var updatedAt: TimeInterval

    /// Verbosity level
    public var verbosityRaw: String?

    /// Reasoning effort level
    public var reasoningEffortRaw: String?

    /// Language preference
    public var languageRaw: String?

    /// Automation level
    public var automationLevelRaw: String?

    /// Provider ID (e.g., "openai")
    public var providerId: String?

    /// Model name (e.g., "gpt-4")
    public var modelName: String?

    /// Associated project path
    public var projectPath: String?

    /// Parent conversation ID for sub-agent conversations
    public var parentConversationID: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        preview: String = "",
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        updatedAt: TimeInterval = Date().timeIntervalSince1970,
        verbosityRaw: String? = nil,
        reasoningEffortRaw: String? = nil,
        languageRaw: String? = nil,
        automationLevelRaw: String? = nil,
        providerId: String? = nil,
        modelName: String? = nil,
        projectPath: String? = nil,
        parentConversationID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.verbosityRaw = verbosityRaw
        self.reasoningEffortRaw = reasoningEffortRaw
        self.languageRaw = languageRaw
        self.automationLevelRaw = automationLevelRaw
        self.providerId = providerId
        self.modelName = modelName
        self.projectPath = projectPath
        self.parentConversationID = parentConversationID
    }
}

// MARK: - Conversion

public extension ConversationModel {
    /// Convert from LumiConversationSummary to ConversationModel
    static func from(summary: LumiConversationSummary) -> ConversationModel {
        let storedTitle = summary.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ConversationModel(
            id: summary.id.uuidString,
            title: storedTitle,
            preview: summary.preview,
            createdAt: summary.createdAt.timeIntervalSince1970,
            updatedAt: summary.updatedAt.timeIntervalSince1970,
            verbosityRaw: summary.verbosity?.rawValue,
            reasoningEffortRaw: summary.reasoningEffort?.rawValue,
            languageRaw: summary.language?.rawValue,
            automationLevelRaw: summary.automationLevel?.rawValue,
            providerId: summary.providerID,
            modelName: summary.modelName,
            projectPath: summary.projectPath,
            parentConversationID: summary.parentConversationID?.uuidString
        )
    }

    /// Convert to LumiConversationSummary
    func toLumiConversationSummary() -> LumiConversationSummary? {
        guard let uuid = UUID(uuidString: id) else { return nil }

        let verbosity: LumiResponseVerbosity? = verbosityRaw.flatMap {
            LumiResponseVerbosity(rawValue: $0)
        }
        let language: LumiConversationLanguage? = languageRaw.flatMap {
            LumiConversationLanguage(rawValue: $0)
        }
        let reasoningEffort: LumiReasoningEffort? = reasoningEffortRaw.flatMap {
            LumiReasoningEffort(rawValue: $0)
        }
        let automationLevel: LumiAutomationLevel? = automationLevelRaw.flatMap {
            LumiAutomationLevel(rawValue: $0)
        }

        return LumiConversationSummary(
            id: uuid,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title,
            preview: preview,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            language: language,
            automationLevel: automationLevel,
            providerID: providerId,
            modelName: modelName,
            projectPath: projectPath,
            parentConversationID: parentConversationID.flatMap(UUID.init(uuidString:))
        )
    }
}
