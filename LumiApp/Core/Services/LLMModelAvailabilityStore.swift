import Combine
import Foundation
import LLMKit
import MagicKit

/// 全局模型可用性存储。
///
/// 数据由可用性检测插件写入；内核请求路径和模型选择 UI 读取。
final class LLMModelAvailabilityStore: ObservableObject, @unchecked Sendable {
    static let shared = LLMModelAvailabilityStore()

    private let lock = NSRecursiveLock()
    private var _providers: [LLMProviderAvailabilityEntry] = []
    private var _isCheckingAll: Bool = false

    var isCheckingAll: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCheckingAll
    }

    var providers: [LLMProviderAvailabilityEntry] {
        lock.lock(); defer { lock.unlock() }
        return _providers
    }

    var availablePairs: [(providerId: String, modelId: String)] {
        lock.lock(); defer { lock.unlock() }
        return _providers.flatMap { provider in
            provider.availableModels.map { modelId in
                (providerId: provider.providerId, modelId: modelId)
            }
        }
    }

    @MainActor
    func initialize(from llmVM: AppLLMVM) {
        initialize(providers: llmVM.allProviders)
    }

    func initialize(providers providersInfo: [LLMProviderInfo]) {
        let providers = providersInfo.map { info in
            LLMProviderAvailabilityEntry(
                providerId: info.id,
                displayName: info.displayName,
                models: info.availableModels.map { modelId in
                    LLMModelAvailabilityEntry(modelId: modelId)
                }
            )
        }

        lock.lock()
        _providers = providers
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func isAvailable(providerId: String, modelId: String) -> Bool {
        status(providerId: providerId, modelId: modelId) == .available
    }

    func status(providerId: String, modelId: String) -> LLMModelAvailabilityStatus? {
        lock.lock(); defer { lock.unlock() }
        guard let provider = _providers.first(where: { $0.providerId == providerId }) else { return nil }
        return provider.models.first(where: { $0.modelId == modelId })?.status
    }

    func updateStatus(providerId: String, modelId: String, status: LLMModelAvailabilityStatus) {
        lock.lock()
        guard let providerIndex = _providers.firstIndex(where: { $0.providerId == providerId }),
              let modelIndex = _providers[providerIndex].models.firstIndex(where: { $0.modelId == modelId }) else {
            lock.unlock()
            return
        }
        _providers[providerIndex].models[modelIndex].status = status
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func setCheckingAll(_ value: Bool) {
        lock.lock()
        _isCheckingAll = value
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func resetAll() {
        lock.lock()
        _providers = []
        _isCheckingAll = false
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func resetAllStatus() {
        lock.lock()
        for i in _providers.indices {
            for j in _providers[i].models.indices {
                _providers[i].models[j].status = .unknown
            }
        }
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
}
