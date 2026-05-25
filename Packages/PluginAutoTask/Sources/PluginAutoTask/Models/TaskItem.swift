import Foundation
import SwiftData

/// AutoTask 插件的任务数据模型
///
/// 存储在插件专属 SQLite 数据库中，由 `TaskStateManager` 管理。
/// 每个任务属于一个会话（conversationId），支持状态追踪和排序。
@Model
final public class TaskItem: @unchecked Sendable {
    /// 唯一标识 (UUID)
    public var id: String

    /// 所属会话 ID
    public var conversationId: String

    /// 任务标题
    public var title: String

    /// 任务详细描述
    public var detail: String?

    /// 任务状态
    public var status: TaskStatus

    /// 排序序号（从 1 开始）
    public var order: Int

    /// 创建时间
    public var createdAt: TimeInterval

    /// 更新时间
    public var updatedAt: TimeInterval

    /// 任务状态枚举
    public enum TaskStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed
        case skipped
    }

    public init(
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
