import Foundation
import KernelLumi

/// Gemma 4 系列（Google）MLX Provider
///
/// 底层推理服务复用 `MLXSeriesProviderBase` 的共享实现。
@available(macOS 14.0, *)
public final class MLXGemma4Provider: MLXSeriesProviderBase, @unchecked Sendable {
    private static let _registration = MLXModels.seriesRegistrations.first { $0.seriesName == "Gemma 4 系列" }!
    public override class var info: LumiLLMProviderInfo { computeInfo(for: _registration) }
    public convenience init() { self.init(registration: Self._registration) }
}
