import Foundation
import MagicKit

/// LLM 可用性检测服务
/// 通过向每个供应商的每个模型发送轻量 ping 请求来检测其可用性
final class LLMAvailabilityChecker: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false

    private let llmService: LLMService
    private let store = LLMAvailabilityStore.shared

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    /// 检测所有供应商+模型的可用性
    func checkAll() async {
        await MainActor.run {
            store.isCheckingAll = true
        }

        let providersInfo = llmService.allProviders()

        // 逐个供应商检测（避免过多并发）
        for providerInfo in providersInfo {
            await checkProvider(providerInfo)
        }

        await MainActor.run {
            store.isCheckingAll = false
        }

        let count = store.availablePairs.count
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 可用性检测完成，共 \(count) 个模型可用")
        }
    }

    /// 检测单个供应商的所有模型
    private func checkProvider(_ info: LLMProviderInfo) async {
        let providerId = info.id

        // 获取该供应商的 API Key
        guard let providerType = llmService.providerType(forId: providerId) else {
            for modelId in info.availableModels {
                await updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("供应商类型未找到"))
            }
            return
        }

        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 如果没有 API Key 且不是本地供应商，标记所有模型为不可用
        if apiKey.isEmpty && !info.isLocal {
            for modelId in info.availableModels {
                await updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("未配置 API Key"))
            }
            return
        }

        // 逐个检测模型
        for modelId in info.availableModels {
            await checkModel(providerId: providerId, modelId: modelId, apiKey: apiKey)
        }
    }

    /// 检测单个模型的可用性
    private func checkModel(providerId: String, modelId: String, apiKey: String) async {
        await updateStatus(providerId: providerId, modelId: modelId, status: .checking)

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
            // 使用带超时的非流式请求进行连通性检测
            try await withTimeout(seconds: 10) {
                _ = try await self.llmService.sendMessage(messages: testMessages, config: config)
            }
            // 请求成功 → 模型可用
            await updateStatus(providerId: providerId, modelId: modelId, status: .available)
        } catch is TimeoutError {
            await updateStatus(providerId: providerId, modelId: modelId, status: .unavailable("请求超时"))
        } catch let error as LLMServiceError {
            switch error {
            case .cancelled:
                // 取消意味着请求已开始执行 → 视为可用
                await updateStatus(providerId: providerId, modelId: modelId, status: .available)
            default:
                await updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(error.errorDescription ?? error.localizedDescription))
            }
        } catch {
            await updateStatus(providerId: providerId, modelId: modelId, status: .unavailable(error.localizedDescription))
        }
    }

    @MainActor
    private func updateStatus(providerId: String, modelId: String, status: LLMAvailabilityStatus) {
        store.updateStatus(providerId: providerId, modelId: modelId, status: status)
    }
}

// MARK: - Timeout Helper

/// 超时错误
struct TimeoutError: Error, LocalizedError {
    let seconds: Double
    var errorDescription: String? {
        "操作超时（\(seconds) 秒）"
    }
}

/// 带超时的异步操作
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(seconds: seconds)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
