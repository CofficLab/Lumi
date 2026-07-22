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

    public init(
        id: String = UUID().uuidString,
        title: String,
        preview: String = "",
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        updatedAt: TimeInterval = Date().timeIntervalSince1970,
        verbosityRaw: String? = nil,
        languageRaw: String? = nil,
        automationLevelRaw: String? = nil,
        providerId: String? = nil,
        modelName: String? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.verbosityRaw = verbosityRaw
        self.languageRaw = languageRaw
        self.automationLevelRaw = automationLevelRaw
        self.providerId = providerId
        self.modelName = modelName
        self.projectPath = projectPath
    }
}

// MARK: - Conversion

public extension ConversationModel {
    /// Convert from LumiConversationSummary to ConversationModel
    static func from(summary: LumiConversationSummary) -> ConversationModel {
        ConversationModel(
            id: summary.id.uuidString,
            title: summary.title,
            preview: summary.preview,
            createdAt: summary.createdAt.timeIntervalSince1970,
            updatedAt: summary.updatedAt.timeIntervalSince1970,
            verbosityRaw: summary.verbosity?.rawValue,
            languageRaw: summary.language?.rawValue,
            automationLevelRaw: summary.automationLevel?.rawValue,
            providerId: summary.providerID,
            modelName: summary.modelName,
            projectPath: summary.projectPath
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
        let automationLevel: LumiAutomationLevel? = automationLevelRaw.flatMap {
            LumiAutomationLevel(rawValue: $0)
        }

        return LumiConversationSummary(
            id: uuid,
            title: title,
            preview: preview,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            verbosity: verbosity,
            language: language,
            automationLevel: automationLevel,
            providerID: providerId,
            modelName: modelName,
            projectPath: projectPath
        )
    }
}
