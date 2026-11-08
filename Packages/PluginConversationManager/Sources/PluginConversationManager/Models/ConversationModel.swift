import Foundation
import KitLLM
import ProviderConversation
import SwiftData

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

    /// Timestamp of the last message received (used for conversation list sorting)
    /// Optional to allow lightweight migration — old records have NULL; callers default to `createdAt`.
    public var lastMessageAt: TimeInterval?

    /// 单调排序键：毫秒时间戳左移 20 位，低 20 位放会话 ID 的稳定哈希。
    ///
    /// 不能把 `id` 当次级排序键：SwiftData 对字符串次级排序不可靠，实测同一批数据
    /// 在多次查询中顺序不同，keyset 分页会因此漏项/重复。数值主键可以保证强一致排序，
    /// 同时 20 位哈希让同一毫秒内的会话仍有稳定且几乎不重复的顺序。
    public var sortKey: Int64 = 0

    /// Verbosity level
    public var verbosityRaw: String?

    /// Reasoning effort level
    public var reasoningEffortRaw: String?

    /// Language preference
    public var languageRaw: String?

    /// Automation level
    public var automationLevelRaw: String?

    /// Lumi 全局唯一模型 ID。新的会话只写入此字段。
    public var modelID: String?

    /// Legacy columns retained for lightweight SwiftData migration; new writes clear them.
    public var providerId: String?
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
        lastMessageAt: TimeInterval? = nil,
        verbosityRaw: String? = nil,
        reasoningEffortRaw: String? = nil,
        languageRaw: String? = nil,
        automationLevelRaw: String? = nil,
        modelID: String? = nil,
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
        self.lastMessageAt = lastMessageAt ?? createdAt
        self.sortKey = ConversationModel.makeSortKey(
            date: lastMessageAt ?? createdAt,
            id: id
        )
        self.verbosityRaw = verbosityRaw
        self.reasoningEffortRaw = reasoningEffortRaw
        self.languageRaw = languageRaw
        self.automationLevelRaw = automationLevelRaw
        self.modelID = modelID.flatMap { LLMModelID(rawValue: $0)?.rawValue } ?? providerId.flatMap { provider in
            modelName.flatMap { LLMModelID(providerID: provider, modelID: $0)?.rawValue }
        }
        self.providerId = nil
        self.modelName = nil
        self.projectPath = projectPath
        self.parentConversationID = parentConversationID
    }
}

// MARK: - Sorting

public extension ConversationModel {
    /// 生成 `(毫秒时间戳, id 哈希)` 的单调排序键，供数据库排序与 keyset 游标共用。
    static func makeSortKey(date: TimeInterval, id: String) -> Int64 {
        let millis = Int64((date * 1_000).rounded())
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        let tiebreak = Int64(hash & 0x000F_FFFF)
        return (millis << 20) | tiebreak
    }
}

// MARK: - Conversion

public extension ConversationModel {
    /// Convert from LumiConversationSummary to ConversationModel
    static func from(summary: ConversationSummary) -> ConversationModel {
        let storedTitle = summary.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ConversationModel(
            id: summary.id.uuidString,
            title: storedTitle,
            preview: summary.preview,
            createdAt: summary.createdAt.timeIntervalSince1970,
            updatedAt: summary.updatedAt.timeIntervalSince1970,
            lastMessageAt: summary.lastMessageAt.timeIntervalSince1970,
            verbosityRaw: summary.verbosity?.rawValue,
            reasoningEffortRaw: summary.reasoningEffort?.rawValue,
            languageRaw: summary.language?.rawValue,
            automationLevelRaw: summary.automationLevel?.rawValue,
            modelID: summary.modelID,
            projectPath: summary.projectPath,
            parentConversationID: summary.parentConversationID?.uuidString
        )
    }

    /// Convert to LumiConversationSummary
    func toLumiConversationSummary() -> ConversationSummary? {
        guard let uuid = UUID(uuidString: id) else { return nil }

        let verbosity: ResponseVerbosity? = verbosityRaw.flatMap {
            ResponseVerbosity(rawValue: $0)
        }
        let language: ConversationLanguage? = languageRaw.flatMap {
            ConversationLanguage(rawValue: $0)
        }
        let reasoningEffort: ReasoningEffort? = reasoningEffortRaw.flatMap {
            ReasoningEffort(rawValue: $0)
        }
        let automationLevel: AutomationLevel? = automationLevelRaw.flatMap {
            AutomationLevel(rawValue: $0)
        }

        return ConversationSummary(
            id: uuid,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title,
            preview: preview,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            lastMessageAt: Date(timeIntervalSince1970: lastMessageAt ?? createdAt),
            verbosity: verbosity,
            reasoningEffort: reasoningEffort,
            language: language,
            automationLevel: automationLevel,
            modelID: modelID ?? legacyModelID,
            projectPath: projectPath,
            parentConversationID: parentConversationID.flatMap(UUID.init(uuidString:))
        )
    }

    private var legacyModelID: String? {
        guard let providerId, let modelName else { return nil }
        return LLMModelID(providerID: providerId, modelID: modelName)?.rawValue
    }
}
