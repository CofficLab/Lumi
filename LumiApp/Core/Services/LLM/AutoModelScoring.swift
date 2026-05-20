import Foundation
import LLMKit

protocol AutoModelScoring: Sendable {
    func score(
        provider: LLMProviderInfo,
        model: String,
        availability: LLMModelAvailabilityStatus?,
        signal: AutoRouteSignal
    ) -> Double
}

struct DefaultAutoModelScoring: AutoModelScoring {
    func score(
        provider: LLMProviderInfo,
        model: String,
        availability: LLMModelAvailabilityStatus?,
        signal: AutoRouteSignal
    ) -> Double {
        var score = 0.0

        switch availability {
        case .available:
            score += 100
        case .checking:
            score += 30
        case .unknown, nil:
            score += 20
        case .unavailable:
            score -= 1_000
        }

        if provider.id == signal.currentProviderId {
            score += 8
        }
        if provider.id == signal.currentProviderId && model == signal.currentModel {
            score += 16
        }

        if signal.messageLength < 280 && model.localizedCaseInsensitiveContains("mini") {
            score += 8
        }
        if signal.messageLength > 2_000 {
            score += Double(provider.contextWindowSizes[model] ?? 0) / 100_000.0
        }

        let lower = model.lowercased()
        if signal.allowsTools && (lower.contains("codex") || lower.contains("coder")) {
            score += 10
        }
        if lower.contains("haiku") || lower.contains("mini") || lower.contains("flash") {
            score += 2
        }

        return score
    }
}
