import Foundation
import SwiftData

/// AutoTask 插件的任务数据模型
///
/// 存储在插件专属 SQLite 数据库中，由 `TaskStateManager` 管理。
/// 每个任务属于一个会话（conversationId），支持状态追踪和排序。
@Model
final class TaskItem: @unchecked Sendable {
    /// 唯一标识 (UUID)
    var id: String

    /// 所属会话 ID
    var conversationId: String

    /// 任务标题
    var title: String

    /// 任务详细描述
    var detail: String?

    /// 任务状态
    var status: TaskStatus

    /// 排序序号（从 1 开始）
    var order: Int

    /// 创建时间
    var createdAt: TimeInterval

    /// 更新时间
    var updatedAt: TimeInterval

    /// 任务状态枚举
    enum TaskStatus: String, Codable {
        case pending
        case inProgress
        case completed
        case skipped
    }

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        title: String,
        detail: String? = nil,
        status: TaskStatus = .pending,
        order: Int = 0
    ) {
        self.id = id
        self.conversationId = conversationId
        self.title = title
        self.detail = detail
        self.status = status
        self.order = order
        let now = Date().timeIntervalSince1970
        self.createdAt = now
        self.updatedAt = now
    }
}
