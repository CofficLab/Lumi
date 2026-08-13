import Foundation
import HttpKit
import LLMKit
import KernelLumi

// MARK: - AvailabilityService

typealias FailureDetail = LumiLLMFailureDetail

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderMiniMax")

    static func checkAvailability(
        provider: MiniMaxTokenPlanProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(provider: provider as any LumiLLMProvider, model: model)
    }

    static func checkAvailability(
        provider: MiniMaxAnthropicProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(provider: provider as any LumiLLMProvider, model: model)
    }

    static func checkAvailability(
        provider: MiniMaxResponsesProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(provider: provider as any LumiLLMProvider, model: model)
    }

    private static func checkAvailability(
        provider: any LumiLLMProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result: LumiModelAvailabilityResult
        do {
            let request = LumiLLMRequest(
                messages: [LumiChatMessage(conversationID: UUID(), role: .user, content: "ping")],
                model: model
            )
            _ = try await provider.send(request)
            result = .available
        } catch {
            result = .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        }
        let mapped = mapUnsupportedModelResult(result)
        cache.write(model: model, result: mapped, timestamp: Date())
        return mapped
    }

    static func mapUnsupportedModelResult(
        _ result: LumiModelAvailabilityResult
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }
        guard isUnsupportedModelFailure(failure) else { return result }
        return .unavailable(
            failure.remapped(
                summary: LumiPluginLocalization.string(
                    "This model is not included in your Token Plan",
                    bundle: .module
                ),
                reason: .unsupportedModel
            )
        )
    }

    static func isUnsupportedModelFailure(_ failure: FailureDetail) -> Bool {
        if failure.reason == .unsupportedModel {
            return true
        }
        let combined = [failure.summary, failure.transportDetails]
            .compactMap { $0 }
            .joined(separator: "\n")
        return isUnsupportedModelResponse(combined)
    }

    static func isUnsupportedModelResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("invalid_parameter")
            || lower.contains("model_not_found")
            || lower.contains("not supported in plan")
    }

    static func isUnsupportedModelError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(_, message) = error {
            return isUnsupportedModelResponse(message)
        }
        return isUnsupportedModelFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }
}
