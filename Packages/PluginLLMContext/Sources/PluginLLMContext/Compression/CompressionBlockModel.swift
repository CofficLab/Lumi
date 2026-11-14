import Foundation
import SwiftData

/// 一个不可变压缩块的持久化模型，归上下文插件所有（#1160）。
///
/// 源 ID 列表以 JSON 字符串存储：SwiftData 对标量字段最稳妥，避免数组属性
/// 的迁移不确定性。DTO 层（`CompressionBlock`）负责编解码回 `[UUID]`。
@Model
final class CompressionBlockModel {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var tier: Int
    var summary: String
    var sourceMessageIDsJSON: String
    var sourceBlockIDsJSON: String
    var coveredThroughMessageID: UUID
    var providerID: String?
    var modelName: String?
    var estimatedTokens: Int
    var createdAt: Date
    var active: Bool
    var schemaVersion: Int

    init(
        id: UUID,
        conversationID: UUID,
        tier: Int,
        summary: String,
        sourceMessageIDsJSON: String,
        sourceBlockIDsJSON: String,
        coveredThroughMessageID: UUID,
        providerID: String?,
        modelName: String?,
        estimatedTokens: Int,
        createdAt: Date,
        active: Bool,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.conversationID = conversationID
        self.tier = tier
        self.summary = summary
        self.sourceMessageIDsJSON = sourceMessageIDsJSON
        self.sourceBlockIDsJSON = sourceBlockIDsJSON
        self.coveredThroughMessageID = coveredThroughMessageID
        self.providerID = providerID
        self.modelName = modelName
        self.estimatedTokens = estimatedTokens
        self.createdAt = createdAt
        self.active = active
        self.schemaVersion = schemaVersion
    }
}