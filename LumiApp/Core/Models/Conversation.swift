import Foundation
import SwiftData

/// 对话会话模型
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var projectId: String?  // 关联的项目路径，nil 表示全局对话
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// 对话级供应商 ID，nil 表示未指定（回退到项目偏好）
    var providerId: String?
    /// 对话级模型名称，nil 表示未指定（回退到项目偏好）
    var model: String?

    @Relationship(deleteRule: .cascade) var messages: [ChatMessageEntity]

    init(id: UUID = UUID(), projectId: String? = nil, title: String = "新对话", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [ChatMessageEntity] = []) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}
