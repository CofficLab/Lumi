
import Foundation
import LumiChatKit
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

/// Model Selector 持有的可用性状态 + 协调器。
///
/// 之前是 `LLMAvailabilityStore`（全局单例） + `LLMAvailabilityRuntime.llmService`
/// （全局单例，从来没被注入） + `LLMAvailabilityChecker` + `LumiProviderAvailabilityAdapter`
/// 四件套。新设计把它们压扁成一个 `ObservableObject`：
///
/// - 状态归 Model Selector 自己管（`@StateObject`），不放在全局单例里。
/// - 真正干活的是 `LumiLLMProvider.checkAvailability(model:)`，本来就是
///   协议方法；这里只是循环调用、汇总结果。
/// - 没有「runtime」需要被外部注入，初始化即可用。
///
/// 持有这个对象的 view 用 `@StateObject`，子 view 用 `@ObservedObject` 读。
@MainActor
public final class ModelAvailabilityState: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🛰"
    public nonisolated static let verbose: Bool = false

    /// providerID → modelID → 检查状态
    @Published public private(set) var states: [String: [String: ModelCheckState]] = [:]

    /// 正在检查中的 provider id 集合，用于显示顶层的 spinner。
    @Published public private(set) var checkingProviderIDs: Set<String> = []

    public init() {}

    // MARK: - Read helpers

    public func state(providerId: String, modelId: String) -> ModelCheckState {
        states[providerId]?[modelId] ?? ModelCheckState()
    }

    /// 该供应商下已通过检测的模型数量。
    public func availableCount(for provider: LumiLLMProviderInfo) -> Int {
        provider.availableModels.reduce(0) { acc, model in
            state(providerId: provider.id, modelId: model).isAvailable ? acc + 1 : acc
        }
    }

    public func isProviderAvailable(_ provider: LumiLLMProviderInfo) -> Bool {
        availableCount(for: provider) > 0
    }

    /// 找到该供应商下第一个适合触发 "重配 API Key" 入口的失败原因。
    /// 仅在 key 已配置、且至少一个模型的失败原因不是 `.unsupportedModel` 时返回。
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

    // MARK: - Write helpers (used by check commands)

    private func setState(providerId: String, modelId: String, _ value: ModelCheckState) {
        var inner = states[providerId] ?? [:]
        inner[modelId] = value
        states[providerId] = inner
    }

    private func clearChecking(providerId: String) {
        checkingProviderIDs.remove(providerId)
    }

    // MARK: - Commands

    /// 检查单个供应商下所有模型的可用性。
    /// 立即把状态切到 .checking，然后逐个调 `provider.checkAvailability(model:)` 写回结果。
    ///
    /// 设计上故意只接 `(LumiLLMProviderInfo, any LumiLLMProvider)` 而不接 chat service：
    /// 状态层不应该反向依赖 LumiChatKit（包依赖方向），由调用方解析好 provider 再传进来。
    public func checkProvider(
        _ provider: LumiLLMProviderInfo,
        providerInstance: any LumiLLMProvider
    ) async {
        checkingProviderIDs.insert(provider.id)
        for model in provider.availableModels {
            setState(providerId: provider.id, modelId: model, ModelCheckState(phase: .checking))
        }

        if Self.verbose {
            ModelSelectorPlugin.logger.info(
                "\(self.t)开始检查 \(provider.displayName) (\(provider.id))，共 \(provider.availableModels.count) 个模型"
            )
        }

        // 串行调用，避免一次性把所有 provider 同时打爆上游。
        // 后续如果需要并发，可以包成 TaskGroup，但 model selector 一次也就看十几个模型，串行够了。
        for model in provider.availableModels {
            let result = await providerInstance.checkAvailability(model: model)
            setState(providerId: provider.id, modelId: model, ModelCheckState(result: result))
        }

        clearChecking(providerId: provider.id)

        let available = availableCount(for: provider)
        if Self.verbose {
            ModelSelectorPlugin.logger.info(
                "\(self.t)检查完成 \(provider.displayName): \(available) / \(provider.availableModels.count) 可用"
            )
        }
    }

    /// 检查所有提供的供应商。
    /// 多个 provider 并发执行，缩短总检测时间；每个 provider 内部仍串行遍历模型。
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

    /// 重置指定供应商的状态。
    public func reset(_ providerId: String) {
        states[providerId] = nil
        checkingProviderIDs.remove(providerId)
    }
}
