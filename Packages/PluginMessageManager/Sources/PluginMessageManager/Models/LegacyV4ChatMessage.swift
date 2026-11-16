import Foundation
import SwiftData

// MARK: - v4 Legacy Message Models (verbatim from Lumi 4.x)
//
// 用于以 SwiftData 打开 v4 旧库 `Core/Lumi.db` 读取历史消息（#394）。
//
// ⚠️ 两个不可违背的硬约束（与 LegacyV4Conversation 相同）:
// 1. 字段名 / 类型 / 可空性 / @Attribute 严禁修改 —— SwiftData 用 schema 比对。
// 2. 【关键】类名必须与 v4 库里的实体名完全一致 —— SwiftData 用「类名」推断实体名
//    并匹配库里的表。v4 库 Z_PRIMARYKEY 表记录的实体名是 ChatMessageEntity /
//    ImageAttachmentEntity。若改类名, SwiftData 会认为库里没有该实体、把原表当
//    孤立删除, 导致 fetch 永远返回空。因此类名不能用前缀, 必须保持 v4 原名。
//
// 只迁移消息与图片附件, 故只需这两个实体（会话由 ConversationManager 插件独立迁移,
// token 统计在 MessageMetricsEntity 表, 实测多为空, 沿袭历史 MessageMigrationJob 不合并）。
// 迁移窗口期结束后本文件整体移除。

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