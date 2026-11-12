import Foundation
import SwiftData

/// 一次幕后 LLM 调用用量的持久化模型，归上下文插件所有。
@Model
final class AuxiliaryUsageModel {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var purposeRaw: String
    var providerID: String?
    var modelName: String?
    var inputTokenCount: Int?
    var outputTokenCount: Int?
    var cachedInputTokenCount: Int?
    var cacheWriteInputTokenCount: Int?
    var cacheTotalInputTokenCount: Int?
    var isEstimated: Bool
    var date: Date
    var sourceLastMessageID: UUID?
    var schemaVersion: Int

    init(
        id: UUID,
        conversationID: UUID,
        purposeRaw: String,
        providerID: String?,
        modelName: String?,
        inputTokenCount: Int?,
        outputTokenCount: Int?,
        cachedInputTokenCount: Int?,
        cacheWriteInputTokenCount: Int?,
        cacheTotalInputTokenCount: Int?,
        isEstimated: Bool,
        date: Date,
        sourceLastMessageID: UUID?,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.conversationID = conversationID
        self.purposeRaw = purposeRaw
        self.providerID = providerID
        self.modelName = modelName
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokenCount = cachedInputTokenCount
        self.cacheWriteInputTokenCount = cacheWriteInputTokenCount
        self.cacheTotalInputTokenCount = cacheTotalInputTokenCount
        self.isEstimated = isEstimated
        self.date = date
        self.sourceLastMessageID = sourceLastMessageID
        self.schemaVersion = schemaVersion
    }
}