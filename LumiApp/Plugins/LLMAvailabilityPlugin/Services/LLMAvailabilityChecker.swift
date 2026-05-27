import Foundation
import LLMKit
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

    // MARK: - 单模型检测结果

    /// 单模型检测的结果
    struct ModelCheckResult: Sendable {
        let providerId: String
        let modelId: String
        let isAvailable: Bool
        let reason: String?
    }

    // MARK: - 全量检测

    /// 检测所有供应商+模型的可用性
    func checkAll() async {
        if Self.verbose {
            let providersInfo = llmService.allProviders()
            let totalModels = providersInfo.reduce(0) { $0 + $1.availableModels.count }
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)🚀 开始可用性检测：\(providersInfo.count) 个供应商，\(totalModels) 个模型")
            }
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
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 可用性检测完成：\(availableCount) / \(totalModelCount) 个模型可用")
            }
        }
    }

    // MARK: - 单模型检测（公开接口）

    /// 检测指定供应商+模型的可用性
    ///
    /// 自动查找 API Key，执行 ping 请求并更新 Store 状态。
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - modelId: 模型 ID
    /// - Returns: 检测结果
    @discardableResult
    func checkModel(providerId: String, modelId: String) async -> ModelCheckResult {
        // 查找供应商类型 → 获取 API Key
        guard let providerType = llmService.providerType(forId: providerId) else {
            let msg = "供应商 `\(providerId)` 未注册"
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(msg))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, reason: msg)
        }

        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 判断是否本地供应商
        let providerInfo = llmService.allProviders().first { $0.id == providerId }
        let isLocal = providerInfo?.isLocal ?? false

        if apiKey.isEmpty && !isLocal {
            let msg = "未配置 API Key"
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(msg))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, reason: msg)
        }

        // 委托给内部实现
        return await performCheck(providerId: providerId, modelId: modelId, apiKey: apiKey)
    }

    // MARK: - 内部实现

    /// 检测单个供应商的所有模型
    private func checkProvider(_ info: LLMProviderInfo) async {
        let providerId = info.id

        if Self.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)📦 检测供应商: \(info.displayName) (\(providerId))，\(info.availableModels.count) 个模型")
            }
        }

        // 获取该供应商的 API Key
        guard let providerType = llmService.providerType(forId: providerId) else {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ 供应商类型未找到: \(providerId)，跳过")
                }
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
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ \(info.displayName) 未配置 API Key，跳过所有模型")
                }
            }
            for modelId in info.availableModels {
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("未配置 API Key"))
            }
            return
        }

        // 逐个检测模型
        for modelId in info.availableModels {
            await performCheck(providerId: providerId, modelId: modelId, apiKey: apiKey)
        }

        let availableCount = store.providers.first(where: { $0.providerId == providerId })?.availableModels.count ?? 0
        if Self.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ \(info.displayName) 检测完成：\(availableCount) / \(info.availableModels.count) 个模型可用")
            }
        }
    }

    /// 检测单个模型的可用性（内部实现）
    private func performCheck(providerId: String, modelId: String, apiKey: String) async -> ModelCheckResult {
        store.updateStatus(providerId: providerId, modelId: modelId, status: .checking)

        // 检查该模型是否为 TTS 模型（不支持对话，无法通过 sendMessage 检测）
        let isTTSModel = isTTSOnlyModel(providerId: providerId, modelId: modelId)
        if isTTSModel {
            // TTS 模型：仅验证 API Key 已配置即可，不发送聊天请求
            if apiKey.isEmpty {
                let isLocal = llmService.allProviders().first(where: { $0.id == providerId })?.isLocal ?? false
                if !isLocal {
                    let msg = "未配置 API Key"
                    store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(msg))
                    return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, reason: msg)
                }
            }
            store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ TTS 模型可用（跳过对话检测）: \(providerId) / \(modelId)")
                }
            }
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, reason: nil)
        }

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
            store.updateStatus(providerId: providerId, modelId: modelId, status: .available)

            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用: \(providerId) / \(modelId)")
                }
            }

            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, reason: nil)
        } catch let error as LLMServiceError {
            switch error {
            case .cancelled:
                // 取消意味着请求已开始执行 → 视为可用
                if Self.verbose {
                    if LLMAvailabilityPlugin.verbose {
                                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用（请求被取消）: \(providerId) / \(modelId)")
                    }
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
                return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, reason: nil)
            default:
                let reason = error.errorDescription ?? error.localizedDescription
                if Self.verbose {
                    if LLMAvailabilityPlugin.verbose {
                                            LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 模型不可用: \(providerId) / \(modelId) - \(reason)")
                    }
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(reason))
                return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, reason: reason)
            }
        } catch {
            let reason = error.localizedDescription
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 检测异常: \(providerId) / \(modelId) - \(reason)")
                }
            }
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(reason))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, reason: reason)
        }
    }

    // MARK: - TTS Detection

    /// 判断模型是否为纯 TTS 模型（不支持对话，不应通过 sendMessage 检测）
    ///
    /// 通过 `LLMModelCapabilities.supportsTTS` 来判断：
    /// 声明了 supportsTTS=true 的模型意味着它主要用于语音合成，
    /// 不是对话模型，发送 chat 请求既不合理也浪费资源。
    private func isTTSOnlyModel(providerId: String, modelId: String) -> Bool {
        guard let providerType = llmService.providerType(forId: providerId),
              let caps = providerType.modelCapabilities[modelId] else {
            return false
        }
        return caps.supportsTTS
    }
}
