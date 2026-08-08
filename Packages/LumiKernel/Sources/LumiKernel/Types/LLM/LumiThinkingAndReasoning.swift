import Foundation

/// 模型对"思考 / 推理强度"能力的支持级别（大统一枚举）。
///
/// 不同的 LLM 提供方对推理强度的档位定义并不统一：
/// - 有些模型完全不支持思考（如纯文本生成模型）。
/// - 有些模型支持 3 档（low / medium / high），典型如 OpenAI GPT-5 / o-series。
/// - 有些模型支持 4 档（low / high / xhigh / max），典型如 Anthropic Claude、DeepSeek V4、Qwen3。
/// - 有些模型只有「开 / 关」开关，没有档位（如 MiniMax-M3：可关闭；M2.x：始终开启）。
///   这种情形下 `reasoningEffort` 不适用，UI 应展示为开关或直接隐藏下拉。
///
/// 整个仓库思考与推理强度的所有建模都收敛到此枚举与 `LumiModelCapabilities.thinkingAndReasoning` 字段，
/// 避免在多个平行字典或多个并列字段中重复表达同一概念。
///
/// 用枚举显式建模可用的档位数，避免消费端假设"开启思考 = 显示 4 档按钮"。
public enum LumiThinkingAndReasoning: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// 不支持思考 / 推理强度可调
    case unsupported
    /// 支持 3 档推理强度：low / medium / high
    case threeLevel
    /// 支持 4 档推理强度：low / high / xhigh / max
    case fourLevel
    /// 只有「开 / 关」开关，没有档位（例如 MiniMax-M3）。
    /// 此模式下 `LumiReasoningEffort.available(for: .toggle) == []`，
    /// UI 不应展示推理档位下拉，而应展示开关或保持当前服务端默认行为。
    case toggle

    /// 是否启用思考（即至少有一档可选或可开关）
    public var isEnabled: Bool {
        self != .unsupported
    }

    /// 是否存在多个推理档位（true → 需要 `LumiReasoningEffort` 下拉；
    /// false → 单一开关或隐藏）。
    public var hasMultipleLevels: Bool {
        switch self {
        case .threeLevel, .fourLevel: true
        case .unsupported, .toggle: false
        }
    }
}
