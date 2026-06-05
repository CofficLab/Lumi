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
    /// 对话级聊天模式，nil 表示未指定（回退到全局偏好）
    var chatMode: String?
    /// 对话级响应详细程度，nil 表示未指定（回退到全局偏好）
    var verbosity: String?
    /// 对话级语言偏好，nil 表示未指定（回退到当前窗口偏好）
    var languagePreference: String?

    @Relationship(deleteRule: .cascade) var messages: [ChatMessageEntity]

    init(
        id: UUID = UUID(),
        projectId: String? = nil,
        title: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        chatMode: String? = nil,
        verbosity: String? = nil,
        languagePreference: String? = nil,
        messages: [ChatMessageEntity] = []
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chatMode = chatMode
        self.verbosity = verbosity
        self.languagePreference = languagePreference
        self.messages = messages
    }
}

extension Conversation {
    var hasStoredTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return "对话-" + formatter.string(from: createdAt)
    }
}
