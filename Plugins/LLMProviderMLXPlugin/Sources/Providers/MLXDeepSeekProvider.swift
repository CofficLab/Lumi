import Foundation
import KernelLumi

/// DeepSeek 系列 MLX Provider
///
/// 底层推理服务复用 `MLXSeriesProviderBase` 的共享实现。
@available(macOS 14.0, *)
public final class MLXDeepSeekProvider: MLXSeriesProviderBase, @unchecked Sendable {
    private static let _registration = MLXModels.seriesRegistrations.first { $0.seriesName == "DeepSeek 系列" }!
    public override class var info: LumiLLMProviderInfo { computeInfo(for: _registration) }
    public convenience init() { self.init(registration: Self._registration) }
}
