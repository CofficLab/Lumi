
import Foundation
import LumiCoreKit

/// Model Selector 内部对单个模型检查进度的快照。
///
/// 之前这部分信息埋在 `LLMAvailabilityStore` 里，并被包成
/// `LLMAvailabilityStatus` 枚举（`.unknown` / `.checking` / `.available` / `.unavailable`）。
/// 那是个不必要的中间层：
/// - 「在不在检查」是 UI 编排层关心的事，不属于协议层的"可不可用"。
/// - `LumiModelAvailabilityResult`（`.available` / `.unavailable`）已经足够描述"实际结果"。
///
/// 新的形状把"检查状态"和"检查结果"两件事明确分开：
/// - `phase` 表达 UI 编排状态（未查 / 在查）
/// - `result` 是 provider 真正 ping 之后返回的 `LumiModelAvailabilityResult`
///
/// 用一个轻量 struct 表示，便于 SwiftUI diff、Equatable、Sendable。
public struct ModelCheckState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case notChecked
        case checking
    }

    public var phase: Phase
    public var result: LumiModelAvailabilityResult?

    public init(phase: Phase = .notChecked, result: LumiModelAvailabilityResult? = nil) {
        self.phase = phase
        self.result = result
    }

    public var isChecking: Bool {
        phase == .checking
    }

    public var isAvailable: Bool {
        if case .available = result { return true }
        return false
    }

    /// 当前结果里附带的 `LumiLLMFailureDetail`，仅在 `.unavailable` 时有值。
    public var failure: LumiLLMFailureDetail? {
        if case .unavailable(let detail) = result { return detail }
        return nil
    }

    /// 当前是否处于「已配置 key，但实际检测失败，且不是 unsupportedModel」状态。
    /// 用于触发内联"重配 API Key"入口。
    ///
    /// - 没有失败结果（`failure == nil`）→ false（既不需要也不应该"重配"）
    /// - 失败 reason 是 `.unsupportedModel`（套餐不含该模型）→ false
    ///   （重配 key 救不了，需要换套餐或换模型）
    /// - 其他情况（401 / 403 / 网络 / 配额耗尽等）→ true
    public var isReconfigurableFailure: Bool {
        guard failure != nil else { return false }
        return failure?.reason != .unsupportedModel
    }
}
