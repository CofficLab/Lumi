import Foundation
import MagicKit

/// LLM 服务
///
/// Lumi 应用的 AI 助手后端服务，负责与各种 LLM 供应商进行通信。
/// 非流式 HTTP 与 SSE 流式逻辑见 `LLMService+HTTP` / `LLMService+SSE`。
class LLMService: SuperLog, @unchecked Sendable {
    /// 日志标识符
    nonisolated static let emoji = "🤖"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 0

    /// 供同模块扩展使用（`LLMService+HTTP` / `LLMService+SSE`）
    nonisolated let registry: LLMProviderRegistry
    nonisolated let llmAPI: LLMAPIService

    /// 初始化 LLM 服务
    /// - Parameter registry: 供应商注册表（由外部创建并注册所有供应商）
    init(registry: LLMProviderRegistry) {
        self.registry = registry
        self.llmAPI = LLMAPIService()
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)✅ LLM 服务已初始化")
        }
    }

    // MARK: - Provider Queries

    /// 获取所有已注册供应商的信息
    ///
    /// - Returns: 供应商信息数组，包含 ID、名称、图标、描述、可用模型、是否本地等
    func allProviders() -> [LLMProviderInfo] {
        registry.allProviders()
    }

    /// 根据 ID 查找供应商类型
    ///
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商类型，如果未找到则返回 nil
    func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        registry.providerType(forId: id)
    }

    /// 创建供应商实例
    ///
    /// 根据供应商 ID 创建对应的供应商实例。
    /// 如果已有缓存实例，则返回缓存的实例。
    ///
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商实例，如果未找到则返回 nil
    func createProvider(id: String) -> (any SuperLLMProvider)? {
        registry.createProvider(id: id)
    }

    // MARK: - Local Model Management

    /// 判断当前配置是否为本地供应商且模型未就绪（将触发加载或等待）。
    /// 用于在发送前展示「正在加载模型」等系统提示。
    func needsLocalModelLoad(config: LLMConfig) async -> Bool {
        guard let provider = registry.createProvider(id: config.providerId) as? any SuperLocalLLMProvider else {
            return false
        }
        let state = await provider.getModelState()
        return state != .ready
    }

    /// 确保本地模型已就绪：若为 .loading/.generating 则轮询等待，若为 .idle/.error 则尝试加载，超时或失败则抛出。
    func ensureLocalModelReady(
        local: any SuperLocalLLMProvider,
        modelId: String,
        timeoutSeconds: Double = 300,
        pollIntervalSeconds: Double = 1
    ) async throws {
        var state = await local.getModelState()
        if state == .ready { return }

        if state == .loading || state == .generating {
            let deadline = CFAbsoluteTimeGetCurrent() + timeoutSeconds
            while CFAbsoluteTimeGetCurrent() < deadline {
                do {
                    try Task.checkCancellation()
                } catch is CancellationError {
                    throw LLMServiceError.cancelled
                }
                state = await local.getModelState()
                if state == .ready { return }
                if case .error = state { break }
                do {
                    try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
                } catch is CancellationError {
                    throw LLMServiceError.cancelled
                }
            }
            if state != .ready {
                throw LLMServiceError.requestFailed("加载超时，请稍后重试或到设置中查看")
            }
            return
        }

        do {
            try await local.loadModel(id: modelId)
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        state = await local.getModelState()
        if state != .ready {
            let msg: String
            if case .error(let s) = state { msg = s } else { msg = "模型未就绪" }
            throw LLMServiceError.requestFailed(msg)
        }
    }
}
