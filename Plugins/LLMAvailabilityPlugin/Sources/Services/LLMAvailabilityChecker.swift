import Foundation
import LLMKit
import LLMProviderKit
import LumiCoreKit
import os
import SuperLogKit

/// LLM 可用性检测服务
/// 通过向每个供应商的每个模型发送轻量 ping 请求来检测其可用性
@MainActor
public final class LLMAvailabilityChecker: SuperLog {
    public static let verbose: Bool = false

    private let llmService: any LLMAvailabilityLLMServicing
    private let store = LLMAvailabilityStore.shared

    public init(llmService: any LLMAvailabilityLLMServicing) {
        self.llmService = llmService
    }

    // MARK: - 单模型检测结果

    /// 单模型检测的结果
    public struct ModelCheckResult: Sendable {
        public let providerId: String
        public let modelId: String
        public let isAvailable: Bool
        public let failure: LumiLLMFailureDetail?

        public var reason: String? { failure?.logSummary }
    }

    // MARK: - 全量检测

    /// 检测所有供应商+模型的可用性
    public func checkAll() async {
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
    @discardableResult
    public func checkModel(providerId: String, modelId: String) async -> ModelCheckResult {
        guard let providerType = llmService.providerType(forId: providerId) else {
            let failure = Self.messageFailure("供应商 `\(providerId)` 未注册")
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(failure))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, failure: failure)
        }

        let providerInfo = llmService.allProviders().first { $0.id == providerId }
        let isLocal = providerInfo?.isLocal ?? false

        if !providerType.hasApiKey && !isLocal {
            let failure = Self.messageFailure("未配置凭证")
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(failure))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, failure: failure)
        }

        return await performCheck(providerId: providerId, modelId: modelId)
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

        guard let providerType = llmService.providerType(forId: providerId) else {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ 供应商类型未找到: \(providerId)，跳过")
                }
            }
            for modelId in info.availableModels {
                store.updateStatus(
                    providerId: providerId,
                    modelId: modelId,
                    status: .unavailable(Self.messageFailure("供应商类型未找到"))
                )
            }
            return
        }

        if !providerType.hasApiKey && !info.isLocal {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)⚠️ \(info.displayName) 未配置凭证，跳过所有模型")
                }
            }
            for modelId in info.availableModels {
                store.updateStatus(
                    providerId: providerId,
                    modelId: modelId,
                    status: .unavailable(Self.messageFailure("未配置凭证"))
                )
            }
            return
        }

        for modelId in info.availableModels {
            await performCheck(providerId: providerId, modelId: modelId)
        }

        let availableCount = store.providers.first(where: { $0.providerId == providerId })?.availableModels.count ?? 0
        if Self.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ \(info.displayName) 检测完成：\(availableCount) / \(info.availableModels.count) 个模型可用")
            }
        }
    }

    /// 检测单个模型的可用性（内部实现）
    private func performCheck(providerId: String, modelId: String) async -> ModelCheckResult {
        store.updateStatus(providerId: providerId, modelId: modelId, status: .checking)

        guard let provider = llmService.createProvider(id: providerId) else {
            let failure = Self.messageFailure("供应商 `\(providerId)` 未注册")
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(failure))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, failure: failure)
        }

        let strategy = provider.availabilityCheckStrategy(forModel: modelId)

        switch strategy {
        case .apiKeyOnly:
            store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                    LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用（apiKeyOnly 策略）: \(providerId) / \(modelId)")
                }
            }
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, failure: nil)

        case .chatPing(let maxTokens):
            return await performChatPing(providerId: providerId, modelId: modelId, maxTokens: maxTokens)

        case .custom(let check):
            let credential = llmService.providerType(forId: providerId)?.getApiKey() ?? ""
            let result = await check(credential, modelId)
            let failure = result.failure ?? Self.messageFailure("检测失败")
            let status: LLMAvailabilityStatus = result.isAvailable ? .available : .unavailable(failure)
            store.updateStatus(providerId: providerId, modelId: modelId, status: status)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                    if result.isAvailable {
                        LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用（custom 策略）: \(providerId) / \(modelId)")
                    } else {
                        LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 模型不可用（custom 策略）: \(providerId) / \(modelId) - \(failure.logSummary)")
                    }
                }
            }
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: result.isAvailable, failure: result.isAvailable ? nil : failure)
        }
    }

    /// 执行标准聊天 ping 检测
    private func performChatPing(providerId: String, modelId: String, maxTokens: Int?) async -> ModelCheckResult {
        var config = LLMConfig(model: modelId, providerId: providerId)
        config.maxTokens = maxTokens ?? 1

        let testMessages: [ChatMessage] = [ChatMessage(role: .user, content: "Hi")]

        do {
            _ = try await llmService.sendMessage(messages: testMessages, config: config)

            store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                    LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用: \(providerId) / \(modelId)")
                }
            }
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, failure: nil)
        } catch let error as LLMServiceError {
            switch error {
            case .cancelled:
                if Self.verbose {
                    if LLMAvailabilityPlugin.verbose {
                        LLMAvailabilityPlugin.logger.info("\(LLMAvailabilityLog.t)✅ 模型可用（请求被取消）: \(providerId) / \(modelId)")
                    }
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .available)
                return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: true, failure: nil)
            default:
                let failure = Self.messageFailure(error.errorDescription ?? error.localizedDescription)
                if Self.verbose {
                    if LLMAvailabilityPlugin.verbose {
                        LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 模型不可用: \(providerId) / \(modelId) - \(failure.logSummary)")
                    }
                }
                store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(failure))
                return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, failure: failure)
            }
        } catch {
            let failure = Self.messageFailure(error.localizedDescription)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                    LLMAvailabilityPlugin.logger.warning("\(LLMAvailabilityLog.t)❌ 检测异常: \(providerId) / \(modelId) - \(failure.logSummary)")
                }
            }
            store.updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(failure))
            return ModelCheckResult(providerId: providerId, modelId: modelId, isAvailable: false, failure: failure)
        }
    }

    private static func messageFailure(_ message: String) -> LumiLLMFailureDetail {
        .message(message)
    }
}
