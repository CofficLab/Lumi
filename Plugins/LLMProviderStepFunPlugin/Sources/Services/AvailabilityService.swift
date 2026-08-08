import Foundation
import LumiKernel

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: stepFunPluginDataDirectoryName)

    static func checkAvailability(
        provider: StepFunProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await ping(provider: provider, model: model)
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
    
    /// 直接使用 StepFunService 的 sendOnce 进行 ping 检测。
    private static func ping(provider: StepFunProvider, model: String) async -> LumiModelAvailabilityResult {
        do {
            try await provider.ping(model: model)
            return .available
        } catch {
            return .unavailable(LumiLLMFailureDetail.message(error.localizedDescription))
        }
    }
}