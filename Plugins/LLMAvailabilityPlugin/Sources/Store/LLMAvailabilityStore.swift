import Combine
import Foundation
import LLMKit
import LumiCoreKit
import SuperLogKit

public enum LLMAvailabilityStatus: Equatable, Sendable {
    case unknown
    case checking
    case available
    case unavailable(LumiLLMFailureDetail)
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

public final class LLMAvailabilityStore: ObservableObject, @unchecked Sendable {
    public static let shared = LLMAvailabilityStore()

    private let lock = NSRecursiveLock()
    private var _providers: [LLMProviderAvailability] = []
    private var _isCheckingAll = false

    public var isCheckingAll: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCheckingAll
    }

    public var providers: [LLMProviderAvailability] {
        lock.lock()
        defer { lock.unlock() }
        return _providers
    }

    public var availablePairs: [(providerId: String, modelId: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _providers.flatMap { provider in
            provider.availableModels.map { (providerId: provider.providerId, modelId: $0) }
        }
    }

    public func initialize(providers providersInfo: [LLMProviderInfo]) {
        let providers = providersInfo.map { info in
            LLMProviderAvailability(
                providerId: info.id,
                displayName: info.displayName,
                models: info.availableModels.map { LLMModelAvailability(modelId: $0) }
            )
        }

        lock.lock()
        _providers = providers
        lock.unlock()
        publishChange()
    }

    /// 使用 `LumiCoreKit.LumiLLMProviderInfo` 初始化（新架构入口）。
    public func initializeFromLumiProviders(_ providersInfo: [LumiLLMProviderInfo]) {
        let providers = providersInfo.map { info in
            LLMProviderAvailability(
                providerId: info.id,
                displayName: info.displayName,
                models: info.availableModels.map { LLMModelAvailability(modelId: $0) }
            )
        }

        lock.lock()
        _providers = providers
        lock.unlock()
        publishChange()
    }

    public func isAvailable(providerId: String, modelId: String) -> Bool {
        status(providerId: providerId, modelId: modelId) == .available
    }

    public func status(providerId: String, modelId: String) -> LLMAvailabilityStatus? {
        lock.lock()
        defer { lock.unlock() }
        guard let provider = _providers.first(where: { $0.providerId == providerId }) else { return nil }
        return provider.models.first(where: { $0.modelId == modelId })?.status
    }

    public func updateStatus(providerId: String, modelId: String, status: LLMAvailabilityStatus) {
        lock.lock()
        guard let providerIndex = _providers.firstIndex(where: { $0.providerId == providerId }),
              let modelIndex = _providers[providerIndex].models.firstIndex(where: { $0.modelId == modelId }) else {
            lock.unlock()
            return
        }
        _providers[providerIndex].models[modelIndex].status = status
        lock.unlock()
        publishChange()
    }

    public func setCheckingAll(_ value: Bool) {
        lock.lock()
        _isCheckingAll = value
        lock.unlock()
        publishChange()
    }

    public func resetAll() {
        lock.lock()
        _providers = []
        _isCheckingAll = false
        lock.unlock()
        publishChange()
    }

    public func resetAllStatus() {
        lock.lock()
        for providerIndex in _providers.indices {
            for modelIndex in _providers[providerIndex].models.indices {
                _providers[providerIndex].models[modelIndex].status = .unknown
            }
        }
        lock.unlock()
        publishChange()
    }

    private func publishChange() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
}

public enum LLMAvailabilityLog: SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose = false
}
