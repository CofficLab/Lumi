import Foundation
import SwiftData

/// Goal 数据模型 - 代表 LLM 要达成的最终目标/意图
///
/// 存储在插件专属 SQLite 数据库中，由 `GoalStateManager` 管理。
/// 每个 Goal 属于一个会话（conversationId），包含多个 Task。
@Model
final public class Goal: @unchecked Sendable {
    /// 唯一标识 (UUID)
    public var id: String
    
    /// 所属会话 ID
    public var conversationId: String
    
    /// 目标标题（简短描述，给用户看）
    public var title: String
    
    /// 目标详细描述（给 LLM 看的上下文）
    public var goalDescription: String?
    
    /// 成功标准（帮助 LLM 判断何时完成）
    public var successCriteria: String?
    
    /// 目标状态
    public var status: GoalStatus
    
    /// 阻塞原因（当 status = blocked 时）
    public var blockedReason: String?
    
    /// 失败原因（当 status = failed 时）
    public var failureReason: String?
    
    /// 创建时间
    public var createdAt: TimeInterval
    
    /// 更新时间
    public var updatedAt: TimeInterval
    
    /// 完成时间
    public var completedAt: TimeInterval?
    
    /// 关系：一个 Goal 有多个 GoalTask（级联删除）
    @Relationship(deleteRule: .cascade)
    public var tasks: [GoalTask] = []
    
    /// 目标状态枚举
    public enum GoalStatus: String, Codable, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed
        case blocked
        case failed
        case skipped
    }
    
    public init(
        id: String = UUID().uuidString,
        conversationId: String,
        title: String,
        goalDescription: String? = nil,
        successCriteria: String? = nil,
        status: GoalStatus = .pending,
        blockedReason: String? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.title = title
        self.goalDescription = goalDescription
        self.successCriteria = successCriteria
        self.status = status
        self.blockedReason = blockedReason
        self.failureReason = failureReason
        let now = Date().timeIntervalSince1970
        self.createdAt = now
        self.updatedAt = now
        self.completedAt = nil
    }
}