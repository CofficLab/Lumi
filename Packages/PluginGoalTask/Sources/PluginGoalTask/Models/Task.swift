import Foundation
import SwiftData

/// GoalTask 数据模型 - 代表为实现 Goal 而执行的具体行动步骤
///
/// 存储在插件专属 SQLite 数据库中，由 `GoalStateManager` 管理。
/// 每个 GoalTask 属于一个 Goal，支持并行执行和状态追踪。
@Model
final public class GoalTask: @unchecked Sendable {
    /// 唯一标识 (UUID)
    public var id: String
    
    /// 所属 Goal ID（外键关联）
    public var goalId: String
    
    /// 任务标题（简短描述，给用户看）
    public var title: String
    
    /// 任务详细描述（给 LLM 看的技术细节）
    public var taskDescription: String?
    
    /// 执行上下文（给 LLM 看的额外信息，如文件路径、API 端点等）
    public var executionContext: String?
    
    /// 任务状态
    public var status: TaskStatus
    
    /// 执行顺序（从 1 开始，支持并行时可为 null）
    public var order: Int
    
    /// 并行组标识（相同 group 的任务可以并发执行）
    public var parallelGroup: String?
    
    /// 执行结果摘要（完成后记录）
    public var result: String?
    
    /// 错误信息（失败时记录）
    public var errorMessage: String?
    
    /// 创建时间
    public var createdAt: TimeInterval
    
    /// 更新时间
    public var updatedAt: TimeInterval
    
    /// 完成时间
    public var completedAt: TimeInterval?
    
    /// 关系：一个 GoalTask 属于一个 Goal
    @Relationship(inverse: \Goal.tasks)
    public var goal: Goal?
    
    /// 任务状态枚举
    public enum TaskStatus: String, Codable, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed
        case failed
        case skipped
    }
    
    public init(
        id: String = UUID().uuidString,
        goalId: String,
        title: String,
        taskDescription: String? = nil,
        executionContext: String? = nil,
        status: TaskStatus = .pending,
        order: Int = 0,
        parallelGroup: String? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.taskDescription = taskDescription
        self.executionContext = executionContext
        self.status = status
        self.order = order
        self.parallelGroup = parallelGroup
        let now = Date().timeIntervalSince1970
        self.createdAt = now
        self.updatedAt = now
        self.completedAt = nil
    }
}