import Foundation

/// 子智能体状态
public enum SubAgentStatus: String, Sendable {
    /// 正在运行
    case running
    /// 已完成
    case completed
    /// 执行失败
    case failed
    /// 已取消
    case cancelled
}

/// 子智能体运行结果
public struct SubAgentResult: Sendable {
    /// 智能体 ID
    public let agentId: String
    /// 最终状态
    public let status: SubAgentStatus
    /// 结果文本（成功时为 LLM 最终回复，失败时为错误信息）
    public let result: String
    /// 使用的供应商 ID
    public let providerId: String
    /// 使用的模型 ID
    public let modelId: String
    /// 执行耗时（秒）
    public let duration: Double
}

/// 子智能体上下文
///
/// 存储单个子智能体的运行时状态，包括其异步任务和结果。
public final class SubAgentContext: @unchecked Sendable {
    /// 智能体唯一标识
    public let agentId: String
    /// 简短描述
    public let description: String
    /// 供应商 ID
    public let providerId: String
    /// 模型 ID
    public let modelId: String
    /// 任务描述
    public let task: String
    /// 创建时间
    public let createdAt: Date

    /// 当前状态
    public var status: SubAgentStatus
    /// 最终结果（完成后设置）
    public var result: SubAgentResult?
    /// 异步任务引用
    public var taskHandle: Task<Void, Never>?

    public init(
        agentId: String,
        description: String,
        providerId: String,
        modelId: String,
        task: String
    ) {
        self.agentId = agentId
        self.description = description
        self.providerId = providerId
        self.modelId = modelId
        self.task = task
        self.createdAt = Date()
        self.status = .running
    }
}
