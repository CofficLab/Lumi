import Foundation
import SwiftData

/// 每次「发出请求」的持久化记录。
///
/// 与 ConversationStore 保持相同的磁盘存储规律:
/// 由 `AgentTurnRecordStore` 使用 SwiftData 持久化到
/// `storage.pluginDataDirectory(for: "AgentTurnRunner")` 下的 SQLite 文件。
@Model
final class AgentTurnRecordModel {
    @Attribute(.unique) var id: String
    var conversationID: String
    var createdAt: Date
    var model: String
    var providerID: String?
    /// 合并后的系统提示词(位于 `messages` 首位的 system 消息原文)。
    var systemPrompt: String
    /// 完整消息列表的 JSON 字符串(`[LumiChatMessage]` 编码后)。
    var messagesJSON: String
    /// 工具列表的 JSON 字符串(`[{name,description,inputSchema}]`)。
    var toolsJSON: String
    var imageAttachmentsCount: Int
    var fileAttachmentsCount: Int

    init(
        id: String,
        conversationID: String,
        createdAt: Date,
        model: String,
        providerID: String?,
        systemPrompt: String,
        messagesJSON: String,
        toolsJSON: String,
        imageAttachmentsCount: Int,
        fileAttachmentsCount: Int
    ) {
        self.id = id
        self.conversationID = conversationID
        self.createdAt = createdAt
        self.model = model
        self.providerID = providerID
        self.systemPrompt = systemPrompt
        self.messagesJSON = messagesJSON
        self.toolsJSON = toolsJSON
        self.imageAttachmentsCount = imageAttachmentsCount
        self.fileAttachmentsCount = fileAttachmentsCount
    }
}
