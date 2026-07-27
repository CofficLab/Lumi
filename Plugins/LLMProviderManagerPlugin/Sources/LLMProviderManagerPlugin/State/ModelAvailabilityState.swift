import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// Model Selector 持有的可用性状态 + 协调器。
@MainActor
public final class ModelAvailabilityState: ObservableObject {
    /// providerID → modelID → 检查状态
    @Published public private(set) var states: [String: [String: ModelCheckState]] = [:]

    /// 正在检查中的 provider id 集合，用于显示顶层的 spinner。
    @Published package var checkingProviderIDs: Set<String> = []

    public init() {}

    // MARK: - Read helpers

    public func state(providerId: String, modelId: String) -> ModelCheckState {
        states[providerId]?[modelId] ?? ModelCheckState()
    }

    public func availableCount(for provider: LumiLLMProviderInfo) -> Int {
        provider.availableModels.reduce(0) { acc, model in
            state(providerId: provider.id, modelId: model).isAvailable ? acc + 1 : acc
        }
    }

    public func isProviderAvailable(_ provider: LumiLLMProviderInfo) -> Bool {
        availableCount(for: provider) > 0
    }

    public func firstReconfigurableFailure(for provider: LumiLLMProviderInfo) -> LumiLLMFailureDetail? {
        for model in provider.availableModels {
            let s = state(providerId: provider.id, modelId: model)
            if s.isReconfigurableFailure, let f = s.failure {
                return f
            }
        }
        return nil
    }

    public func isChecking(providerId: String) -> Bool {
        checkingProviderIDs.contains(providerId)
    }

    // MARK: - Write helpers

    package func setState(providerId: String, modelId: String, _ value: ModelCheckState) {
        var inner = states[providerId] ?? [:]
        inner[modelId] = value
        states[providerId] = inner
    }

    private func clearChecking(providerId: String) {
        checkingProviderIDs.remove(providerId)
    }

    // MARK: - Commands

    public func checkProvider(
        _ provider: LumiLLMProviderInfo,
        providerInstance: any LumiLLMProvider
    ) async {
        checkingProviderIDs.insert(provider.id)
        for model in provider.availableModels {
            setState(providerId: provider.id, modelId: model, ModelCheckState(phase: .checking))
        }

        for model in provider.availableModels {
            let result = await providerInstance.checkAvailability(model: model)
            setState(providerId: provider.id, modelId: model, ModelCheckState(result: result))
        }

        clearChecking(providerId: provider.id)
    }

    public func checkAll(
        _ items: [(info: LumiLLMProviderInfo, instance: any LumiLLMProvider)]
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for (info, instance) in items {
                group.addTask {
                    await self.checkProvider(info, providerInstance: instance)
                }
            }
        }
    }

    public func reset(_ providerId: String) {
        states[providerId] = nil
        checkingProviderIDs.remove(providerId)
    }

    public func markAllPending(_ providers: [LumiLLMProviderInfo]) {
        for provider in providers {
            checkingProviderIDs.insert(provider.id)
            for model in provider.availableModels {
                setState(providerId: provider.id, modelId: model, ModelCheckState(phase: .checking))
            }
        }
    }
}
