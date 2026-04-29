import Foundation
import MagicKit
import SwiftUI

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

/// LLM 可用性存储
/// 维护当前实际可用的供应商+模型列表
@MainActor
final class LLMAvailabilityStore: ObservableObject {
    static let shared = LLMAvailabilityStore()

    @Published var providers: [LLMProviderAvailability] = []
    @Published var isCheckingAll: Bool = false

    /// 获取所有可用的供应商+模型对
    var availablePairs: [(providerId: String, modelId: String)] {
        providers.flatMap { provider in
            provider.availableModels.map { modelId in
                (providerId: provider.providerId, modelId: modelId)
            }
        }
    }

    /// 检查指定供应商+模型对是否可用
    func isAvailable(providerId: String, modelId: String) -> Bool {
        guard let provider = providers.first(where: { $0.providerId == providerId }) else {
            return false
        }
        guard let model = provider.models.first(where: { $0.modelId == modelId }) else {
            return false
        }
        return model.status == .available
    }

    /// 初始化可用性列表（从 LLMVM 获取所有供应商+模型）
    func initialize(from llmVM: LLMVM) {
        let providersInfo = llmVM.allProviders
        self.providers = providersInfo.map { info in
            LLMProviderAvailability(
                providerId: info.id,
                displayName: info.displayName,
                models: info.availableModels.map { modelId in
                    LLMModelAvailability(modelId: modelId)
                }
            )
        }
    }

    /// 更新指定模型的可用性状态
    func updateStatus(providerId: String, modelId: String, status: LLMAvailabilityStatus) {
        guard let providerIndex = providers.firstIndex(where: { $0.providerId == providerId }) else { return }
        guard let modelIndex = providers[providerIndex].models.firstIndex(where: { $0.modelId == modelId }) else { return }
        providers[providerIndex].models[modelIndex].status = status
    }

    /// 重置所有状态为未知
    func resetAllStatus() {
        for i in providers.indices {
            for j in providers[i].models.indices {
                providers[i].models[j].status = .unknown
            }
        }
    }
}
