import Foundation
import MagicKit
import os

/// LLM 可用性检测服务
/// 通过向每个供应商的每个模型发送轻量 ping 请求来检测其可用性
final class LLMAvailabilityChecker {
    static let verbose: Bool = false

    private let llmService: LLMService
    private let store = LLMAvailabilityStore.shared

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    /// 检测所有供应商+模型的可用性
    func checkAll() async {
        if Self.verbose {
            let providersInfo = llmService.allProviders()
            let totalModels = providersInfo.reduce(0) { $0 + $1.availableModels.count }
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)🚀 开始可用性检测：\(providersInfo.count) 个供应商，\(totalModels) 个模型")
        }

        store.setCheckingAll(true)

        let providersInfo = llmService.allProviders()

        for providerInfo in providersInfo {
            await checkProvider(providerInfo)
        }

        store.setCheckingAll(false)

        let availableCount = store.availablePairs.count
        let totalModelCount = store.providers.reduce(0) { $0 + $1.models.count }

        if Self.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 可用性检测完成：\(availableCount) / \(totalModelCount) 个模型可用")
        }
    }

    /// 检测单个供应商的所有模型
    private func checkProvider(_ info: LLMProviderInfo) async {
        let providerId = info.id

        if Self.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)📦 检测供应商: \(info.displayName) (\(providerId))，\(info.availableModels.count) 个模型")
        }

        // 获取该供应商的 API Key
        guard let providerType = llmService.providerType(forId: providerId) else {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ 供应商类型未找到: \(providerId)，跳过")
            }
            for modelId in info.availableModels {
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("供应商类型未找到"))
            }
            return
        }

        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 如果没有 API Key 且不是本地供应商，标记所有模型为不可用
        if apiKey.isEmpty && !info.isLocal {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ \(info.displayName) 未配置 API Key，跳过所有模型")
            }
            for modelId in info.availableModels {
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("未配置 API Key"))
            }
            return
        }

        // 逐个检测模型
        for modelId in info.availableModels {
            await checkModel(providerId: providerId, modelId: modelId, apiKey: apiKey)
        }

        let availableCount = store.providers.first(where: { $0.providerId == providerId })?.availableModels.count ?? 0
        if Self.verbose {
            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ \(info.displayName) 检测完成：\(availableCount) / \(info.availableModels.count) 个模型可用")
        }
    }

    /// 检测单个模型的可用性
    private func checkModel(providerId: String, modelId: String, apiKey: String) async {
        store.updateStatus(providerId: providerId, modelId: modelId, status: .checking)

        let config = LLMConfig(
            apiKey: apiKey,
            model: modelId,
            providerId: providerId
        )

        // 构建最小测试请求（单条简短消息）
        let testMessages: [ChatMessage] = [
            ChatMessage(role: .user, conversationId: UUID(), content: "Hi")
        ]

        do {
            // 直接调用 sendMessage 进行连通性检测
            // URLSession 已配置 300s 超时，对于 ping 场景已足够
            _ = try await llmService.sendMessage(messages: testMessages, config: config)

            // 请求成功 → 模型可用
            if Self.verbose {
                LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用: \(providerId) / \(modelId)")
            }
        } catch let error as LLMServiceError {
            switch error {
            case .cancelled:
                // 取消意味着请求已开始执行 → 视为可用
                if Self.verbose {
                    LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用（请求被取消）: \(providerId) / \(modelId)")
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
            default:
                if Self.verbose {
                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 模型不可用: \(providerId) / \(modelId) - \(error.errorDescription ?? error.localizedDescription)")
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(error.errorDescription ?? error.localizedDescription))
            }
        } catch {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 检测异常: \(providerId) / \(modelId) - \(error.localizedDescription)")
            }
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(error.localizedDescription))
        }
    }
}
