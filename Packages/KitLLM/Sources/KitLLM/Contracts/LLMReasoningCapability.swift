import Foundation

/// 模型的思考（推理）能力契约。
///
/// 「关闭思考」在不同模型上的实际效果并不一致：
/// - 有的模型接受 `thinking: {"type": "disabled"}`，能真正停止思考；
/// - 有的模型**强制思考**（传入 disabled 直接返回 400），只能降档；
/// - 有的模型既不能关、也不认档位参数。
///
/// 同一个「关闭」开关在不同模型上语义完全不同，UI 与请求构建必须读同一份
/// 声明，否则就会出现「明明关了思考，消息里还是有思考过程」。
public struct LLMReasoningCapability: Sendable, Equatable, Codable {

    /// 关闭思考时服务端实际生效的策略。
    public enum OffStrategy: Sendable, Equatable, Codable {
        /// 不下发任何推理参数：服务端按自身默认行为思考（关不掉）。
        case omitParameters
        /// 下发 `thinking: {"type": "disabled"}`：服务端真正停止思考。
        case disableThinkingParameter
        /// 降为指定档位：模型强制思考，只能降档、不能关闭。
        case lowestEffort(String)
    }

    /// 该模型接受的推理档位；空表示不支持档位调节。
    public let supportedEfforts: [String]

    /// 关闭思考的实际生效策略。
    public let offStrategy: OffStrategy

    public init(supportedEfforts: [String] = [], offStrategy: OffStrategy = .omitParameters) {
        self.supportedEfforts = supportedEfforts
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.offStrategy = offStrategy
    }

    /// 模型能否真正停止思考。
    public var supportsDisabling: Bool {
        offStrategy == .disableThinkingParameter
    }

    /// 关闭思考是否会降档（而非真正关闭）。
    public var degradesToLowestEffort: Bool {
        if case .lowestEffort = offStrategy { return true }
        return false
    }

    /// 关闭思考时实际生效的档位；不降档时为 `nil`。
    public var lowestEffort: String? {
        if case .lowestEffort(let effort) = offStrategy { return effort }
        return nil
    }
}
