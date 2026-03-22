import Foundation
import MagicKit

extension LLMService {
    // MARK: - 非流式（HTTP）

    /// 发送消息到指定的 LLM 供应商（单次 HTTP 请求）。
    ///
    /// - Throws: 仅 `LLMServiceError`
    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [AgentTool]? = nil) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let provider = registry.createProvider(id: config.providerId) else {
            AppLogger.core.error("\(self.t)未找到供应商：\(config.providerId)")
            return LLMServiceError.providerNotFound(providerId: config.providerId).toChatMessage()
        }

        let isLocal = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocal {
            do {
                try config.validate()
            } catch let error as LLMServiceError {
                return error.toChatMessage()
            }
        }

        if let local = provider as? any SuperLocalLLMProvider {
            try await ensureLocalModelReady(local: local, modelId: config.model)
            let images = messages.last(where: { $0.role == .user }).map(\.images) ?? []
            let msg: ChatMessage
            do {
                msg = try await local.sendMessage(
                    messages: messages,
                    model: config.model,
                    tools: tools,
                    systemPrompt: nil,
                    images: images
                )
            } catch let e as LLMServiceError {
                throw e
            } catch is CancellationError {
                throw LLMServiceError.cancelled
            } catch {
                throw LLMServiceError.requestFailed(error.localizedDescription)
            }
            return msg
        }

        let baseURLString = provider.baseURL
        AppLogger.core.info("\(self.t)构建 API URL：\(baseURLString)")
        guard let url = URL(string: baseURLString) else {
            AppLogger.core.error("\(self.t)无效的 URL: \(baseURLString)")
            return LLMServiceError.invalidBaseURL(baseURLString).toChatMessage()
        }

        let body: [String: Any]
        do {
            body = try provider.buildRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
        } catch {
            AppLogger.core.error("\(self.t)构建请求体失败：\(error.localizedDescription)")
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }

        do {
            var additionalHeaders: [String: String] = [:]
            if config.providerId == "zhipu" {
                additionalHeaders["anthropic-version"] = "2023-06-01"
            }

            let data: Data
            do {
                data = try await llmAPI.sendChatRequest(
                    url: url,
                    apiKey: config.apiKey,
                    body: body,
                    additionalHeaders: additionalHeaders
                )
            } catch {
                throw LLMServiceError.requestFailed(error.localizedDescription)
            }

            let (content, toolCalls) = try provider.parseResponse(data: data)

            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000.0

            return ChatMessage(
                role: .assistant,
                content: content,
                toolCalls: toolCalls,
                providerId: config.providerId,
                modelName: config.model,
                latency: latency,
                temperature: config.temperature,
                maxTokens: config.maxTokens
            )

        } catch let e as LLMServiceError {
            throw e
        } catch let apiError as APIError {
            throw LLMServiceError.requestFailed(apiError.localizedDescription)
        } catch {
            throw LLMServiceError.requestFailed(error.localizedDescription)
        }
    }
}
