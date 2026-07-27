import Foundation
import SwiftData

// MARK: - v4 Legacy Models (verbatim from Lumi 4.x)
//
// 这 6 个 @Model 是从 v4.19.0 的 LumiChatKit 原样照搬的,用于以 SwiftData 打开
// v4 旧库 `Core/Lumi.db` 读取历史数据。
//
// ⚠️ 两个不可违背的硬约束:
// 1. 字段名 / 类型 / 可空性 / @Attribute 严禁修改 —— SwiftData 用 schema 比对。
// 2. 【关键】类名必须与 v4 库里的实体名完全一致 —— SwiftData 用「类名」推断实体名
//    并匹配库里的表。v4 库 Z_PRIMARYKEY 表记录的实体名是 Conversation / ChatMessageEntity
//    / ChatStateEntity / ImageAttachmentEntity / MessageMetricsEntity / ToolCallEntity。
//    若改类名(如加 LegacyV4 前缀),SwiftData 会认为库里没有该实体、把原表当孤立删除,
//    导致 fetch 永远返回空。因此类名不能用前缀,必须保持 v4 原名。
//
// 这些类只在本插件内使用,与 v5 的 ConversationModel / MessageModel(不同类名)
// 分属不同 module,不会冲突。迁移窗口期结束后本文件整体移除。
//
// 特征(经核对):
// - 无任何 @Relationship 声明,表间仅靠 UUID 字段手动关联。
// - 全部使用 Foundation 基础类型,无自定义枚举依赖。
// - 主键均带 @Attribute(.unique)。

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var projectId: String?
    var title: String
    var preview: String
    var createdAt: Date
    var updatedAt: Date
    var providerId: String?
    var model: String?
    var chatMode: String?
    var verbosity: String?
    var languagePreference: String?

    init(
        id: UUID = UUID(),
        projectId: String? = nil,
        title: String,
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerId: String? = nil,
        model: String? = nil,
        chatMode: String? = nil,
        verbosity: String? = nil,
        languagePreference: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerId = providerId
        self.model = model
        self.chatMode = chatMode
        self.verbosity = verbosity
        self.languagePreference = languagePreference
    }
}

@Model
final class ChatMessageEntity {
    @Attribute(.unique) var id: UUID
    var conversationId: UUID
    var role: String
    var content: String
    var timestamp: Date
    var providerId: String?
    var modelName: String?
    var isError: Bool
    var rawErrorDetail: String?
    var renderKind: String?
    var metadataJSON: String?
    var toolCallsJSON: String?
    var toolCallID: String?
    var reasoningContent: String?

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: String,
        content: String,
        timestamp: Date = Date(),
        providerId: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        renderKind: String? = nil,
        metadataJSON: String? = nil,
        toolCallsJSON: String? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.providerId = providerId
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadataJSON = metadataJSON
        self.toolCallsJSON = toolCallsJSON
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
    }
}

@Model
final class ImageAttachmentEntity {
    @Attribute(.unique) var id: UUID
    var messageId: UUID?
    var data: Data
    var mimeType: String
    var createdAt: Date

    init(id: UUID = UUID(), messageId: UUID? = nil, data: Data, mimeType: String, createdAt: Date = Date()) {
        self.id = id
        self.messageId = messageId
        self.data = data
        self.mimeType = mimeType
        self.createdAt = createdAt
    }
}

@Model
final class ToolCallEntity {
    @Attribute(.unique) var id: String
    var messageId: UUID
    var name: String
    var arguments: String
    var resultContent: String?
    var resultIsError: Bool
    var resultExecutedAt: Date?
    var resultDuration: TimeInterval?
    var displayName: String?
    var createdAt: Date

    init(
        id: String,
        messageId: UUID,
        name: String,
        arguments: String,
        resultContent: String? = nil,
        resultIsError: Bool = false,
        resultExecutedAt: Date? = nil,
        resultDuration: TimeInterval? = nil,
        displayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messageId = messageId
        self.name = name
        self.arguments = arguments
        self.resultContent = resultContent
        self.resultIsError = resultIsError
        self.resultExecutedAt = resultExecutedAt
        self.resultDuration = resultDuration
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

@Model
final class MessageMetricsEntity {
    @Attribute(.unique) var messageId: UUID
    var latency: Double?
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
    var timeToFirstToken: Double?
    var streamingDuration: Double?
    var thinkingDuration: Double?
    var finishReason: String?
    var requestId: String?
    var temperature: Double?
    var maxTokens: Int?
    var thinkingContent: String?
    var hasThinking: Bool

    init(messageId: UUID) {
        self.messageId = messageId
        self.hasThinking = false
    }
}

@Model
final class ChatStateEntity {
    @Attribute(.unique) var id: String
    var selectedConversationID: UUID?
    var selectedProviderID: String?
    var selectedModel: String?
    var routingMode: String?

    init(
        id: String = "default",
        selectedConversationID: UUID? = nil,
        selectedProviderID: String? = nil,
        selectedModel: String? = nil,
        routingMode: String? = nil
    ) {
        self.id = id
        self.selectedConversationID = selectedConversationID
        self.selectedProviderID = selectedProviderID
        self.selectedModel = selectedModel
        self.routingMode = routingMode
    }
}
