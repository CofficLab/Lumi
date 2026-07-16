import Foundation

/// 模型评分协议
///
/// 为单个候选模型打分。外部可实现此协议来替换默认评分策略。
public protocol ModelScoring: Sendable {
    /// 为候选模型打分
    ///
    /// - Parameters:
    ///   - candidate: 候选模型
    ///   - signal: 路由信号
    /// - Returns: 评分（越高越优先）
    func score(candidate: RouteCandidate, signal: RouteSignal) -> Double
}

// MARK: - 默认评分策略

/// 默认评分策略
///
/// 评分规则：
///
/// | 因素 | 分值 | 说明 |
/// |---|---|---|
/// | 可用性 `.available` | +100 | 检测通过的模型大幅加分 |
/// | 可用性 `.checking` | +30 | 正在检测 |
/// | 可用性 `.unknown` | +20 | 未检测过 |
/// | 当前供应商相同 | +8 | 倾向保持当前供应商 |
/// | 供应商 + 模型都相同 | +16 | 强倾向保持当前选择（含上面 +8） |
/// | 短消息 + mini 模型 | +8 | 短对话用小模型更高效 |
/// | 长消息（>2000字） | +上下文窗口/10万 | 长对话倾向大窗口模型 |
/// | 需要工具 + codex/coder | +10 | 编码任务用代码模型 |
/// | haiku/mini/flash | +2 | 快速模型轻微加分 |
public struct DefaultModelScoring: ModelScoring {

    public init() {}

    public func score(candidate: RouteCandidate, signal: RouteSignal) -> Double {
        var score = 0.0

        // 可用性
        switch candidate.availability {
        case .available:
            score += 100
        case .checking:
            score += 30
        case .unknown:
            score += 20
        }

        // 惯性偏好：倾向保持当前选择
        if candidate.providerId == signal.currentProviderId {
            score += 8
        }
        if candidate.providerId == signal.currentProviderId
            && candidate.model == signal.currentModel {
            score += 16
        }

        // 消息长度与模型匹配
        if signal.messageLength < 280
            && candidate.model.localizedCaseInsensitiveContains("mini") {
            score += 8
        }
        if signal.messageLength > 2_000 {
            score += Double(candidate.contextWindowSizes[candidate.model] ?? 0) / 100_000.0
        }

        // 任务类型与模型匹配
        let lower = candidate.model.lowercased()
        if signal.allowsTools && (lower.contains("codex") || lower.contains("coder")) {
            score += 10
        }
        if lower.contains("haiku") || lower.contains("mini") || lower.contains("flash") {
            score += 2
        }

        return score
    }
}
