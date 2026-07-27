import Foundation
import LumiKernel

/// Model Selector 内部对单个模型检查进度的快照。
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

    public var failure: LumiLLMFailureDetail? {
        if case .unavailable(let detail) = result { return detail }
        return nil
    }

    public var isReconfigurableFailure: Bool {
        guard failure != nil else { return false }
        return failure?.reason != .unsupportedModel
    }
}
