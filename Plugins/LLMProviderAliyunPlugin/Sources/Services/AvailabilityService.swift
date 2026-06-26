import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

enum AvailabilityService {
    static func checkAvailability(
        provider: AliyunProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        let result = await provider.checkAvailabilityUsingChatPing(model: model)
        return mapUnsupportedModelResult(result)
    }

    static func mapUnsupportedModelResult(
        _ result: LumiModelAvailabilityResult
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }
        guard isUnsupportedModelFailure(failure) else { return result }

        return .unavailable(
            .unsupportedModel(
                LumiPluginLocalization.string(
                    "This model is not included in your Coding Plan",
                    bundle: .module
                )
            )
        )
    }

    static func isUnsupportedModelFailure(_ failure: LumiLLMFailureDetail) -> Bool {
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
    }

    static func isUnsupportedModelError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(_, message) = error {
            return isUnsupportedModelResponse(message)
        }

        return isUnsupportedModelFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }
}
