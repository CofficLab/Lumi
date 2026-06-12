import Foundation

/// 模型路由器
///
/// 纯算法组件：输入候选列表 + 路由信号，输出最优决策。
/// 不依赖任何外部服务，所有数据由外部提供。
///
/// ## 使用方式
///
/// ```swift
/// let router = ModelRouter()
/// let decision = router.route(candidates: candidates, signal: signal)
/// ```
///
/// 外部负责：
/// 1. 收集所有可用的候选模型（从供应商注册表、可用性检测等）
/// 2. 过滤掉不符合硬性条件的候选（无 API Key、能力不匹配、不可用等）
/// 3. 将过滤后的候选列表传入 `route(candidates:signal:)`
///
/// Package 负责：
/// 1. 对每个候选评分
/// 2. 排序选出最优
/// 3. 返回决策结果
public final class ModelRouter: Sendable {

    private let scoring: ModelScoring

    /// 使用默认评分策略
    public init() {
        self.scoring = DefaultModelScoring()
    }

    /// 使用自定义评分策略
    public init(scoring: ModelScoring) {
        self.scoring = scoring
    }

    /// 从候选列表中选出最优模型
    ///
    /// - Parameters:
    ///   - candidates: 外部已过滤的候选模型列表
    ///   - signal: 当前请求的路由信号
    /// - Returns: 最优决策；若候选列表为空则返回 nil
    public func route(candidates: [RouteCandidate], signal: RouteSignal) -> RouteDecision? {
        guard !candidates.isEmpty else { return nil }

        let scored: [(candidate: RouteCandidate, score: Double)] = candidates.map { candidate in
            (candidate: candidate, score: scoring.score(candidate: candidate, signal: signal))
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.providerDisplayName < rhs.candidate.providerDisplayName
            }
            return lhs.score > rhs.score
        }

        guard let best = scored.first else { return nil }

        let reason = Self.buildReason(candidate: best.candidate, signal: signal)

        return RouteDecision(
            providerId: best.candidate.providerId,
            providerDisplayName: best.candidate.providerDisplayName,
            model: best.candidate.model,
            reason: reason,
            score: best.score
        )
    }

    // MARK: - 决策理由

    private static func buildReason(candidate: RouteCandidate, signal: RouteSignal) -> String {
        var parts: [String] = []

        if signal.hasImages {
            parts.append("支持图片")
        }
        if signal.allowsTools {
            parts.append("支持工具")
        }

        switch candidate.availability {
        case .available:
            parts.append("可用性检测通过")
        case .checking:
            parts.append("正在检测")
        case .unknown:
            parts.append("尚未检测")
        }

        if candidate.providerId == signal.currentProviderId
            && candidate.model == signal.currentModel {
            parts.append("保持当前选择")
        }

        return parts.isEmpty ? "基础路由选择" : parts.joined(separator: "，")
    }
}
