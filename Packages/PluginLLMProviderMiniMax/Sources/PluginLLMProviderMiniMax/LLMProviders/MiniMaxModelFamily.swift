import Foundation
import KitLLM

/// MiniMax 模型家族元数据推断。
///
/// 上游 `/v1/models` **不返回**上下文窗口与视觉能力——实测国内站
/// `GET /v1/models` 与 Anthropic 兼容端点 `/anthropic/v1/models` 都只有
/// `id / object / created / owned_by`（Anthropic 端点为
/// `id / type / display_name / created_at`），没有任何能力字段。因此
/// 远程拉到的模型必须按 id 推导元数据，否则上下文窗口会落到
/// `LLMContextBudget` 的 32K 兜底，远小于模型真实容量。
///
/// 家族规格（官方文档 + 服务端 `max_tokens` 上限探测，双向印证）：
///
/// | 家族 | 上下文窗口 | 视觉输入 |
/// |------|-----------|---------|
/// | M3.x | 1,000,000 | 支持图片 / 视频 |
/// | M2.x | 204,800   | 仅文本与工具调用 |
///
/// 探测依据：服务端对超大 `max_tokens` 返回
/// `model[MiniMax-M3] does not support max tokens > 524288`（M3 官方说明
/// 「1M 上下文、保障至少 512K 可用」）与
/// `model[MiniMax-M2.7] does not support max tokens > 196608`（204,800 的 96%）。
///
/// - Note: 官方文档同时明确「M2.7、M2.5、M2.1 和 M2 系列仅支持文本与工具
///   调用相关内容块，不支持图片和视频输入」，故 M2.x 一律 `supportsVision = false`。
///
/// - Important: M2 系列已在上游下线（官方《模型列表》标为「历史模型」），
///   但本枚举**仍保留 m2 分支**：远程 `/v1/models` 可能短暂返回退役前的
///   缓存条目，且其它供应商（阿里云百炼、腾讯 TokenHub）仍在托管
///   MiniMax-M2.x 模型。家族规则描述的是「这个 id 是什么规格的模型」，
///   与「上游是否还在提供」是两个正交的事实——后者由 `isRetired` 表达。
enum MiniMaxModelFamily: Sendable, Equatable {

    /// M3 系列：1M 上下文，原生多模态。
    case m3
    /// M2 系列：204,800 上下文，纯文本。
    case m2
    /// 无法识别的系列（未来新增的命名规则等），不做任何假设。
    case unknown

    // MARK: - 常量

    /// M3 系列上下文窗口。
    static let m3ContextWindowSize = 1_000_000
    /// M2 系列上下文窗口。
    static let m2ContextWindowSize = 204_800

    // MARK: - 推断

    /// 按模型 id 推断所属家族。
    ///
    /// 识别 `MiniMax-M<主版本号>` 形式的主版本号：
    /// `MiniMax-M3.1-Flash` → `.m3`、`MiniMax-M2.7-highspeed` → `.m2`。
    /// 无法识别时返回 `.unknown`，**不猜测**。
    static func family(for modelID: String) -> MiniMaxModelFamily {
        guard let major = majorVersion(of: modelID) else { return .unknown }
        switch major {
        case 3: return .m3
        case 2: return .m2
        default: return .unknown
        }
    }

    /// 上下文窗口大小；未知家族返回 `nil`（交由上层按兜底值处理）。
    var contextWindowSize: Int? {
        switch self {
        case .m3: return Self.m3ContextWindowSize
        case .m2: return Self.m2ContextWindowSize
        case .unknown: return nil
        }
    }

    /// 是否支持图片输入。
    var supportsVision: Bool {
        switch self {
        case .m3: return true
        case .m2, .unknown: return false
        }
    }

    /// 为远程返回的模型 id 补全元数据。
    ///
    /// 未知家族不补上下文窗口（保持 `nil`），避免用错误的值覆盖真实能力。
    static func enriched(_ modelID: String) -> LLMModelInfo {
        let family = family(for: modelID)
        return LLMModelInfo(
            id: modelID,
            contextWindowSize: family.contextWindowSize,
            supportsVision: family.supportsVision,
            reasoning: reasoningCapability(for: modelID)
        )
    }

    // MARK: - 思考能力

    /// 官方文档给出的思考能力（2026-11）：
    ///
    /// - **M3.1-Flash**：强制开启思考，传入 `thinking: {"type": "disabled"}`
    ///   或 `reasoning_effort: "none"` 都会返回 400；思考深度用
    ///   `reasoning_effort` 调节（low / medium / high / xhigh / max，省略时
    ///   默认 `max`）。
    /// - **M3**：默认开启 adaptive thinking，传入 `thinking: {"type":
    ///   "disabled"}` 可真正关闭；但 `reasoning_effort` 只对 M3.1-Flash
    ///   生效，M3 上会被忽略。
    /// - **M2.x**：思考无法关闭，传入 disabled 虽被接受但不生效。
    ///
    /// 未知家族不声明能力（返回 `nil`），按通用行为处理。
    static func reasoningCapability(for modelID: String) -> LLMReasoningCapability? {
        switch family(for: modelID) {
        case .m3:
            guard (minorVersion(of: modelID) ?? 0) >= 1 else {
                // M3：可关闭，但不支持档位调节。
                return LLMReasoningCapability(
                    supportedEfforts: [],
                    offStrategy: .disableThinkingParameter
                )
            }
            // M3.1：强制思考，只能降档；关闭 = 最低档位。
            return LLMReasoningCapability(
                supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
                offStrategy: .lowestEffort("low")
            )
        case .m2:
            // M2.x：关不掉，也不认档位参数。
            return LLMReasoningCapability(
                supportedEfforts: [],
                offStrategy: .omitParameters
            )
        case .unknown:
            return nil
        }
    }

    /// 抽取模型 id 中的次版本号（`MiniMax-M3.1-Flash` → 1；`MiniMax-M3` → 0）。
    ///
    /// 次版本号决定 M3.1 与 M3 的思考能力差异，必须单独解析。
    static func minorVersion(of modelID: String) -> Int? {
        var rest = modelID
        if rest.lowercased().hasPrefix("minimax") {
            rest = String(rest.dropFirst("MiniMax".count))
        }
        if rest.hasPrefix("-") {
            rest = String(rest.dropFirst())
        }
        if rest.lowercased().hasPrefix("m") {
            rest = String(rest.dropFirst())
        }
        let majorDigits = rest.prefix { $0.isASCII && $0.isNumber }
        guard !majorDigits.isEmpty else { return nil }
        var remainder = rest.dropFirst(majorDigits.count)
        guard remainder.hasPrefix(".") else { return 0 }
        remainder = remainder.dropFirst()
        let minorDigits = remainder.prefix { $0.isASCII && $0.isNumber }
        guard !minorDigits.isEmpty else { return 0 }
        return Int(minorDigits)
    }

    // MARK: - 私有

    /// 抽取模型 id 中的主版本号。
    ///
    /// 依次剥离可选的 `MiniMax` 前缀、`-` 分隔符与 `M` 前缀，随后读取开头的
    /// 连续 ASCII 数字作为主版本号。
    private static func majorVersion(of modelID: String) -> Int? {
        var rest = modelID
        if rest.lowercased().hasPrefix("minimax") {
            rest = String(rest.dropFirst("MiniMax".count))
        }
        if rest.hasPrefix("-") {
            rest = String(rest.dropFirst())
        }
        if rest.lowercased().hasPrefix("m") {
            rest = String(rest.dropFirst())
        }
        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }
}
