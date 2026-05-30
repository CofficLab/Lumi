import Combine
import Foundation
import LLMKit
import LumiCoreKit

public enum LLMAvailabilityStatus: Equatable, Sendable {
    case unknown
    case checking
    case available
    case unavailable(String)
}

public struct LLMModelAvailability: Identifiable, Equatable, Sendable {
    public let modelId: String
    public var status: LLMAvailabilityStatus

    public var id: String { modelId }

    public init(modelId: String, status: LLMAvailabilityStatus = .unknown) {
        self.modelId = modelId
        self.status = status
    }
}

public struct LLMProviderAvailability: Identifiable, Equatable, Sendable {
    public let providerId: String
    public let displayName: String
    public var models: [LLMModelAvailability]

    public var id: String { providerId }

    public var availableModels: [String] {
        models.compactMap { $0.status == .available ? $0.modelId : nil }
    }

    public var hasAvailableModels: Bool {
        !availableModels.isEmpty
    }

    public init(providerId: String, displayName: String, models: [LLMModelAvailability]) {
        self.providerId = providerId
        self.displayName = displayName
        self.models = models
    }
}

@MainActor
public final class LLMAvailabilityStore: ObservableObject {
    public static let shared = LLMAvailabilityStore()

    @Published public var providers: [LLMProviderAvailability] = []
    @Published public var isCheckingAll: Bool = false

    public var availablePairs: [(providerId: String, modelId: String)] {
        providers.flatMap { provider in
            provider.availableModels.map { (provider.providerId, $0) }
        }
    }

    public func initialize(from providers: [LLMProviderInfoLike]) {
        self.providers = providers.map { provider in
            LLMProviderAvailability(
                providerId: provider.id,
                displayName: provider.displayName,
                models: provider.availableModels.map { LLMModelAvailability(modelId: $0) }
            )
        }
    }

    public func initialize(from llmVM: AppLLMVM) {
        initialize(from: llmVM.allProviders)
    }

    public func status(providerId: String, modelId: String) -> LLMAvailabilityStatus? {
        providers
            .first(where: { $0.providerId == providerId })?
            .models
            .first(where: { $0.modelId == modelId })?
            .status
    }
}

public protocol LLMProviderInfoLike {
    var id: String { get }
    var displayName: String { get }
    var availableModels: [String] { get }
}

extension LLMProviderInfo: LLMProviderInfoLike {}

public struct ModelPerformanceStats: Sendable {
    public let providerId: String
    public let modelName: String
    public var sampleCount: Int
    public var avgLatency: Double
    public var avgTTFT: Double
    public var avgInputTokens: Int
    public var avgOutputTokens: Int
    public var avgTPS: Double

    public init(
        providerId: String,
        modelName: String,
        sampleCount: Int = 0,
        avgLatency: Double = 0,
        avgTTFT: Double = 0,
        avgInputTokens: Int = 0,
        avgOutputTokens: Int = 0,
        avgTPS: Double = 0
    ) {
        self.providerId = providerId
        self.modelName = modelName
        self.sampleCount = sampleCount
        self.avgLatency = avgLatency
        self.avgTTFT = avgTTFT
        self.avgInputTokens = avgInputTokens
        self.avgOutputTokens = avgOutputTokens
        self.avgTPS = avgTPS
    }
}
