import Foundation
import os
import MagicKit

/// 供应商+模型可用性状态
enum LLMAvailabilityStatus: Equatable, Sendable {
    /// 未检测
    case unknown
    /// 检测中
    case checking
    /// 可用
    case available
    /// 不可用（包含错误原因）
    case unavailable(String)
}

/// 单个模型的可用性信息
struct LLMModelAvailability: Identifiable, Equatable, Sendable {
    /// 模型 ID
    let modelId: String
    /// 可用性状态
    var status: LLMAvailabilityStatus = .unknown

    var id: String { modelId }
}

/// 单个供应商的可用性信息
struct LLMProviderAvailability: Identifiable, Equatable, Sendable {
    /// 供应商 ID
    let providerId: String
    /// 供应商显示名称
    let displayName: String
    /// 模型可用性列表
    var models: [LLMModelAvailability]

    var id: String { providerId }

    /// 可用的模型列表
    var availableModels: [String] {
        models.compactMap { $0.status == .available ? $0.modelId : nil }
    }

    /// 是否有任意可用模型
    var hasAvailableModels: Bool {
        !availableModels.isEmpty
    }
}

/// LLM 可用性日志辅助（非 MainActor 隔离，供 Store / Checker 使用）
enum LLMAvailabilityLog: SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
}

/// LLM 可用性存储
/// 维护当前实际可用的供应商+模型列表
final class LLMAvailabilityStore: @unchecked Sendable {
    static let shared = LLMAvailabilityStore()

    private let lock = NSRecursiveLock()
    private var _providers: [LLMProviderAvailability] = []
    private var _isCheckingAll: Bool = false

    var isCheckingAll: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCheckingAll
    }

    /// 初始化可用性列表（从 LLMVM 获取所有供应商+模型）
    @MainActor
    func initialize(from llmVM: LLMVM) {
        let providersInfo = llmVM.allProviders
        let providers = providersInfo.map { info in
            LLMProviderAvailability(
                providerId: info.id,
                displayName: info.displayName,
                models: info.availableModels.map { modelId in
                    LLMModelAvailability(modelId: modelId)
                }
            )
        }

        lock.lock()
        _providers = providers
        lock.unlock()

        if LLMAvailabilityLog.verbose {
            let totalModels = providers.reduce(0) { $0 + $1.models.count }
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)📋 已初始化 \(providers.count) 个供应商，共 \(totalModels) 个模型")
        }
    }

    /// 获取所有可用的供应商+模型对
    var availablePairs: [(providerId: String, modelId: String)] {
        lock.lock(); defer { lock.unlock() }
        return _providers.flatMap { provider in
            provider.availableModels.map { modelId in
                (providerId: provider.providerId, modelId: modelId)
            }
        }
    }

    /// 获取供应商快照（只读）
    var providers: [LLMProviderAvailability] {
        lock.lock(); defer { lock.unlock() }
        return _providers
    }

    /// 检查指定供应商+模型对是否可用
    func isAvailable(providerId: String, modelId: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let provider = _providers.first(where: { $0.providerId == providerId }) else { return false }
        guard let model = provider.models.first(where: { $0.modelId == modelId }) else { return false }
        return model.status == .available
    }

    /// 更新指定模型的可用性状态
    func updateStatus(providerId: String, modelId: String, status: LLMAvailabilityStatus) {
        lock.lock()
        guard let providerIndex = _providers.firstIndex(where: { $0.providerId == providerId }),
              let modelIndex = _providers[providerIndex].models.firstIndex(where: { $0.modelId == modelId }) else {
            lock.unlock()
            return
        }
        _providers[providerIndex].models[modelIndex].status = status
        lock.unlock()

        switch status {
        case .checking:
            if LLMAvailabilityLog.verbose {
                LLMAvailabilityPlugin.logger.debug("\(LLMAvailabilityLog.t)🔍 检测中: \(providerId) / \(modelId)")
            }
        case .available:
            if LLMAvailabilityLog.verbose {
                LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 可用: \(providerId) / \(modelId)")
            }
        case .unavailable(let reason):
            if LLMAvailabilityLog.verbose {
                LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 不可用: \(providerId) / \(modelId) - \(reason)")
            }
        case .unknown:
            break
        }
    }

    /// 标记检测开始/结束
    func setCheckingAll(_ value: Bool) {
        lock.lock()
        _isCheckingAll = value
        lock.unlock()

        if LLMAvailabilityLog.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)\(value ? "🚀 开始" : "🏁 结束")全局可用性检测")
        }
    }

    /// 重置所有状态为未知
    func resetAllStatus() {
        lock.lock()
        for i in _providers.indices {
            for j in _providers[i].models.indices {
                _providers[i].models[j].status = .unknown
            }
        }
        lock.unlock()

        if LLMAvailabilityLog.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)🔄 已重置所有检测状态")
        }
    }
}
