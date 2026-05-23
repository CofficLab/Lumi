import Foundation

// MARK: - 输入：路由信号

/// 路由信号，描述当前请求的上下文特征。
///
/// 由外部（App 层）构建，描述本轮 LLM 请求需要什么样的模型能力。
public struct RouteSignal: Sendable, Equatable {
    /// 消息中是否包含图片
    public let hasImages: Bool

    /// 消息总字符数
    public let messageLength: Int

    /// 是否需要工具调用能力
    public let allowsTools: Bool

    /// 当前选中的供应商 ID（用于惯性偏好）
    public let currentProviderId: String

    /// 当前选中的模型名称（用于惯性偏好）
    public let currentModel: String

    public init(
        hasImages: Bool,
        messageLength: Int,
        allowsTools: Bool,
        currentProviderId: String,
        currentModel: String
    ) {
        self.hasImages = hasImages
        self.messageLength = messageLength
        self.allowsTools = allowsTools
        self.currentProviderId = currentProviderId
        self.currentModel = currentModel
    }
}

// MARK: - 输入：候选模型

/// 候选模型的可用性状态
public enum CandidateAvailability: Sendable, Equatable {
    /// 检测通过，可用
    case available
    /// 正在检测中
    case checking
    /// 未检测过
    case unknown
}

/// 候选模型，由外部（App 层）从已注册供应商中收集并传入。
///
/// 外部负责：
/// - 过滤掉未启用的供应商
/// - 过滤掉没有 API Key 的远程供应商
/// - 过滤掉能力不匹配的模型（不支持图片/工具）
/// - 过滤掉不可用的模型
///
/// Package 只对传入的候选列表做评分和排序。
public struct RouteCandidate: Sendable, Equatable {
    /// 供应商 ID
    public let providerId: String

    /// 供应商显示名称
    public let providerDisplayName: String

    /// 模型名称
    public let model: String

    /// 模型可用性
    public let availability: CandidateAvailability

    /// 供应商的上下文窗口映射（模型名 → Token 数）
    public let contextWindowSizes: [String: Int]

    public init(
        providerId: String,
        providerDisplayName: String,
        model: String,
        availability: CandidateAvailability,
        contextWindowSizes: [String: Int] = [:]
    ) {
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.model = model
        self.availability = availability
        self.contextWindowSizes = contextWindowSizes
    }
}

// MARK: - 输出：路由决策

/// 路由决策结果
public struct RouteDecision: Sendable, Equatable {
    /// 选中的供应商 ID
    public let providerId: String

    /// 选中的供应商显示名称
    public let providerDisplayName: String

    /// 选中的模型名称
    public let model: String

    /// 决策理由（人类可读）
    public let reason: String

    /// 该候选的评分（调试用）
    public let score: Double

    public init(
        providerId: String,
        providerDisplayName: String,
        model: String,
        reason: String,
        score: Double
    ) {
        self.providerId = providerId
        self.providerDisplayName = providerDisplayName
        self.model = model
        self.reason = reason
        self.score = score
    }
}
