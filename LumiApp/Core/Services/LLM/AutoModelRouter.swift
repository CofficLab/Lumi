import Foundation
import LLMKit
import MagicKit

struct AutoRouteSignal: Sendable {
    let hasImages: Bool
    let chatMode: ChatMode
    let messageLength: Int
    let allowsTools: Bool
    let currentProviderId: String
    let currentModel: String
}

struct AutoRouteResult: Sendable {
    let config: LLMConfig
    let providerDisplayName: String
    let reason: String
}

struct AutoModelCandidate: Sendable {
    let provider: LLMProviderInfo
    let model: String
    let score: Double
    let reason: String
}

final class AutoModelRouter: @unchecked Sendable {
    private let llmService: LLMService
    private let availabilityStore: LLMModelAvailabilityStore
    private let scoring: AutoModelScoring

    init(
        llmService: LLMService,
        availabilityStore: LLMModelAvailabilityStore = .shared,
        scoring: AutoModelScoring = DefaultAutoModelScoring()
    ) {
        self.llmService = llmService
        self.availabilityStore = availabilityStore
        self.scoring = scoring
    }

    func route(signal: AutoRouteSignal) -> AutoRouteResult? {
        let candidates = makeCandidates(signal: signal)
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.provider.displayName < rhs.provider.displayName
                }
                return lhs.score > rhs.score
            }

        guard let best = candidates.first else { return nil }

        let apiKey = apiKey(for: best.provider.id) ?? ""
        return AutoRouteResult(
            config: LLMConfig(apiKey: apiKey, model: best.model, providerId: best.provider.id),
            providerDisplayName: best.provider.displayName,
            reason: best.reason
        )
    }

    private func makeCandidates(signal: AutoRouteSignal) -> [AutoModelCandidate] {
        llmService.allProviders().flatMap { provider -> [AutoModelCandidate] in
            guard provider.isEnabled else { return [] }

            if !provider.isLocal, apiKey(for: provider.id)?.isEmpty != false {
                return []
            }

            return provider.availableModels.compactMap { model in
                guard passesRequiredCapabilities(provider: provider, model: model, signal: signal) else {
                    return nil
                }

                let availability = availabilityStore.status(providerId: provider.id, modelId: model)
                if case .unavailable = availability {
                    return nil
                }

                let score = scoring.score(
                    provider: provider,
                    model: model,
                    availability: availability,
                    signal: signal
                )

                return AutoModelCandidate(
                    provider: provider,
                    model: model,
                    score: score,
                    reason: reason(provider: provider, model: model, availability: availability, signal: signal)
                )
            }
        }
    }

    private func passesRequiredCapabilities(
        provider: LLMProviderInfo,
        model: String,
        signal: AutoRouteSignal
    ) -> Bool {
        if provider.isLocal {
            return true
        }

        guard let caps = llmService.providerType(forId: provider.id)?.modelCapabilities[model] else {
            return !signal.hasImages && !signal.allowsTools
        }

        if signal.hasImages && !caps.supportsVision {
            return false
        }
        if signal.allowsTools && !caps.supportsTools {
            return false
        }
        return true
    }

    private func apiKey(for providerId: String) -> String? {
        guard let providerType = llmService.providerType(forId: providerId) else {
            return nil
        }
        return APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey)
    }

    private func reason(
        provider: LLMProviderInfo,
        model: String,
        availability: LLMModelAvailabilityStatus?,
        signal: AutoRouteSignal
    ) -> String {
        var parts: [String] = []
        if signal.hasImages {
            parts.append("支持图片")
        }
        if signal.allowsTools {
            parts.append("支持工具")
        }
        switch availability {
        case .available:
            parts.append("可用性检测通过")
        case .checking:
            parts.append("正在检测")
        case .unknown, nil:
            parts.append("尚未检测")
        case .unavailable:
            break
        }
        if provider.id == signal.currentProviderId && model == signal.currentModel {
            parts.append("保持当前选择")
        }
        return parts.isEmpty ? "基础路由选择" : parts.joined(separator: "，")
    }
}
