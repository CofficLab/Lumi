import Foundation
import AgentToolKit
import HttpKit
import LLMKit
import LumiCoreKit

/// LLM 服务
///
/// Lumi 应用的 AI 助手后端服务，负责与各种 LLM 供应商进行通信。
class LLMService: SuperLog, @unchecked Sendable {
    /// 日志标识符
    nonisolated static let emoji = "🤖"

    /// 详细日志级别
    /// 0: 关闭日志
    /// 1: 基础日志
    /// 2: 详细日志（输出请求/响应的详细信息）
    nonisolated static let verbose = 0

    /// 供同模块扩展使用
    nonisolated let registry: LLMProviderRegistry

    /// 初始化 LLM 服务
    /// - Parameter registry: 供应商注册表（由外部创建并注册所有供应商）
    init(registry: LLMProviderRegistry) {
        self.registry = registry
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)✅ LLM 服务已初始化")
        }
    }

    // MARK: - Provider Queries

    /// 获取所有已注册供应商的信息
    func allProviders() -> [LLMProviderInfo] {
        registry.allProviders()
    }

    /// 根据 ID 查找供应商类型
    func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        registry.providerType(forId: id)
    }

    /// 创建供应商实例
    func createProvider(id: String) -> (any SuperLLMProvider)? {
        registry.createProvider(id: id)
    }

    // MARK: - Local Model Management

    /// 判断当前配置是否为本地供应商且模型未就绪（将触发加载或等待）。
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
        try await local.ensureModelReady(
            modelId: modelId,
            timeoutSeconds: timeoutSeconds,
            pollIntervalSeconds: pollIntervalSeconds
        )
    }

    // MARK: - LLM Send

    /// 发送消息到指定的 LLM 供应商（单次请求）。
    ///
    /// - Throws: 仅 `LLMServiceError`
    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [SuperAgentTool]? = nil) async throws -> ChatMessage {
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let provider = registry.createProvider(id: config.providerId) else {
            AppLogger.core.error("\(self.t)未找到供应商：\(config.providerId)")
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage(conversationId: conversationId)
        }

        do {
            return try await provider.sendMessage(messages: messages, config: config, tools: tools)
        } catch let error as LLMServiceError {
            switch error {
            case .apiKeyEmpty, .modelEmpty, .providerIdEmpty, .temperatureOutOfRange, .maxTokensInvalid, .invalidBaseURL:
                return error.toChatMessage(conversationId: conversationId, providerId: config.providerId)
            default:
                throw error
            }
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }

    /// 流式发送消息，通过 `onChunk` 回调增量内容。
    ///
    /// - Throws: 仅 `LLMServiceError`
    @discardableResult
    func sendStreamingMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]? = nil,
        onChunk: @Sendable @escaping (StreamChunk) async -> Void,
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in }
    ) async throws -> ChatMessage {
        let conversationId = messages.first?.conversationId ?? UUID()

        guard let provider = registry.createProvider(id: config.providerId) else {
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage(conversationId: conversationId)
        }

        let apiKeyLen = registry.providerType(forId: config.providerId)?
            .getApiKey()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .count ?? -1
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)🤖 [LLMService] streamChat provider=\(config.providerId) model=\(config.model) apiKeyLen=\(apiKeyLen) tools=\(tools?.count ?? 0)")
        }

        do {
            return try await provider.streamChat(
                messages: messages,
                config: config,
                tools: tools,
                maxThinkingLength: AgentConfig.maxThinkingTextLength,
                onChunk: onChunk,
                onRequestStart: onRequestStart
            )
        } catch let error as LLMServiceError {
            throw error
        } catch is CancellationError {
            throw LLMServiceError.cancelled
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }
}

// MARK: - LLMServiceError → ChatMessage

extension LLMServiceError {
    /// 转为可落库消息：使用 `ChatMessage+Error` 中的工厂方法创建错误消息
    /// - Parameter conversationId: 会话 ID
    /// - Parameter providerId: 供应商 ID（可选，用于 API Key 缺失错误）
    func toChatMessage(conversationId: UUID, providerId: String? = nil) -> ChatMessage {
        switch self {
        case .apiKeyEmpty:
            let pid = providerId ?? ""
            return ChatMessage.apiKeyMissingMessage(providerId: pid, conversationId: conversationId)
        case .modelEmpty:
            return ChatMessage.llmModelEmptyMessage(conversationId: conversationId)
        case .providerIdEmpty:
            return ChatMessage.llmProviderIdEmptyMessage(conversationId: conversationId)
        case let .temperatureOutOfRange(v):
            return ChatMessage.llmTemperatureInvalidMessage(temperature: v, conversationId: conversationId)
        case let .maxTokensInvalid(v):
            return ChatMessage.llmMaxTokensInvalidMessage(maxTokens: v, conversationId: conversationId)
        case let .providerNotFound(providerId):
            return ChatMessage.llmProviderNotFoundMessage(providerId: providerId, conversationId: conversationId)
        case let .invalidBaseURL(urlString):
            return ChatMessage.llmInvalidBaseURLMessage(baseURL: urlString, conversationId: conversationId)
        case .cancelled:
            return ChatMessage.cancelledMessage(conversationId: conversationId)
        case let .requestFailed(message, _):
            return ChatMessage.llmRequestFailedMessage(message: message, conversationId: conversationId)
        }
    }
}
