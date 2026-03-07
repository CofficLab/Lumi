import Combine
import SwiftUI
import Foundation
import OSLog
import MagicKit

/// LLM 服务
///
/// Lumi 应用的 AI 助手后端服务，负责与各种 LLM 供应商进行通信。
///
/// ## 支持的供应商
///
/// - OpenAI (GPT-4, GPT-3.5)
/// - Anthropic (Claude)
/// - DeepSeek
/// - 智谱 (Zhipu)
/// - 阿里云 (Aliyun)
///
/// ## 使用示例
///
/// ```swift
/// let llmService = LLMService()
///
/// let messages = [
///     ChatMessage(role: .user, content: "你好")
/// ]
///
/// let config = LLMConfig(
///     providerId: "openai",
///     model: "gpt-4",
///     apiKey: "sk-..."
/// )
///
/// let response = try await llmService.sendMessage(messages: messages, config: config)
/// print(response.content)
/// ```
class LLMService: SuperLog, @unchecked Sendable {
    /// 日志标识符
    nonisolated static let emoji = "🤖"
    
    /// 是否启用详细日志
    /// 设为 true 时会输出请求/响应的详细信息
    nonisolated static let verbose = true

    /// 供应商注册表
    ///
    /// 管理所有支持的 LLM 供应商。
    /// 负责创建供应商实例和提供供应商元数据。
    private nonisolated let registry: ProviderRegistry
    
    /// LLM API 服务
    ///
    /// 负责实际的网络请求。
    /// 处理 HTTP 连接、请求/响应序列化、错误处理等。
    private nonisolated let llmAPI: LLMAPIService

    /// 供应商注册表（公开访问）
    ///
    /// 允许外部代码查询已注册的供应商信息。
    nonisolated var providerRegistry: ProviderRegistry { registry }

    /// 初始化 LLM 服务
    ///
    /// 创建供应商注册表和 API 服务实例。
    init() {
        self.registry = ProviderRegistry()
        self.llmAPI = LLMAPIService()
        if Self.verbose {
            os_log("\(self.t)✅ LLM 服务已初始化")
        }
    }

    // MARK: - 发送消息

    /// 发送消息到指定的 LLM 供应商
    ///
    /// 将消息历史发送到选定的 LLM 提供商，获取 AI 助手的回复。
    /// 支持函数调用（Tool Calls）功能。
    ///
    /// - Parameters:
    ///   - messages: 消息历史，包含用户、助手、AI 的消息
    ///   - config: LLM 配置，包含供应商、模型、API Key 等
    ///   - tools: 可用工具列表，用于函数调用
    ///
    /// - Returns: AI 助手的回复消息
    ///
    /// - Throws:
    ///   - NSError (code 401): API Key 为空
    ///   - NSError (code 404): 供应商未找到
    ///   - NSError (code 400): 无效的 Base URL
    ///   - NSError (code 500): API 请求失败
    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [AgentTool]? = nil) async throws -> ChatMessage {
        // 验证 API Key
        guard !config.apiKey.isEmpty else {
            os_log(.error, "\(self.t)API Key 为空")
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing"])
        }

        // 记录开始时间，用于计算延迟
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从注册表获取供应商实例
        guard let provider = registry.createProvider(id: config.providerId) else {
            os_log(.error, "\(self.t)未找到供应商：\(config.providerId)")
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"])
        }

        // 构建 API URL
        guard let url = URL(string: provider.baseURL) else {
            os_log(.error, "\(self.t)无效的 URL: \(provider.baseURL)")
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(provider.baseURL)"])
        }

        // 构建请求体
        let body: [String: Any]
        do {
            body = try provider.buildRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: "" // 系统提示已包含在 messages 中
            )
        } catch {
            os_log(.error, "\(self.t)构建请求体失败：\(error.localizedDescription)")
            throw error
        }

        // 输出调试信息
        if Self.verbose {
            os_log("\(self.t)🚀 发送请求到 \(config.providerId): \(config.model)")

            if let tools = tools, !tools.isEmpty {
                os_log("\(self.t)📦 发送工具列表 (\(tools.count) 个):")
                for tool in tools {
                    os_log("\(self.t)  - \(tool.name): \(tool.description)")
                }
            } else {
                os_log("\(self.t)📦 无工具")
            }
        }

        // 发送请求到 LLM API
        do {
            // 构建额外的请求头
            var additionalHeaders: [String: String] = [:]

            // 为 Anthropic 兼容的 API 添加 anthropic-version 请求头
            // 智谱 (Zhipu) 也需要此请求头
            if config.providerId == "zhipu" {
                additionalHeaders["anthropic-version"] = "2023-06-01"
            }

            if Self.verbose && !additionalHeaders.isEmpty {
                os_log("\(self.t)📦 添加额外请求头：\(additionalHeaders)")
            }

            // 发送聊天请求
            let data = try await llmAPI.sendChatRequest(
                url: url,
                apiKey: config.apiKey,
                body: body,
                additionalHeaders: additionalHeaders
            )

            // 解析响应
            let (content, toolCalls) = try provider.parseResponse(data: data)

            // 计算总耗时（毫秒）
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000.0

            // 输出响应信息
            if Self.verbose {
                if let toolCalls = toolCalls, !toolCalls.isEmpty {
                    os_log("\(self.t)收到响应：\(content.prefix(10))...，包含 \(toolCalls.count) 个工具调用，耗时：\(String(format: "%.2f", latency))ms")
                } else {
                    os_log("\(self.t)收到响应：「\(content.prefix(10))...」，耗时：\(String(format: "%.2f", latency))ms")
                }
            }

            // 返回助手消息（包含请求参数）
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

        } catch let apiError as APIError {
            // 转换 API 错误为 NSError，保留错误描述
            throw NSError(
                domain: "LLMService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: apiError.localizedDescription]
            )
        }
    }

    // MARK: - 流式发送消息

    /// 流式发送消息到 LLM
    ///
    /// 使用 SSE 协议接收流式响应，通过回调实时返回内容片段
    ///
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - config: LLM 配置
    ///   - tools: 可用工具列表
    ///   - onChunk: 收到内容片段时的回调
    /// - Returns: 完整的助手消息（包含累积的内容和工具调用）
    /// - Throws: API 错误
    func sendStreamingMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]? = nil,
        onChunk: @Sendable @escaping (StreamChunk) -> Void
    ) async throws -> ChatMessage {
        // 验证 API Key
        guard !config.apiKey.isEmpty else {
            os_log(.error, "\(self.t)API Key 为空")
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing"])
        }

        // 记录开始时间
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从注册表获取供应商实例
        guard let provider = registry.createProvider(id: config.providerId) else {
            os_log(.error, "\(self.t)未找到供应商：\(config.providerId)")
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"])
        }

        // 构建 API URL
        guard let url = URL(string: provider.baseURL) else {
            os_log(.error, "\(self.t)无效的 URL: \(provider.baseURL)")
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(provider.baseURL)"])
        }

        // 构建流式请求体
        let body: [String: Any]
        do {
            body = try provider.buildStreamingRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
        } catch {
            os_log(.error, "\(self.t)构建流式请求体失败：\(error.localizedDescription)")
            throw error
        }

        // 输出调试信息
        if Self.verbose {
            os_log("\(self.t)🚀 发送流式请求到 \(config.providerId): \(config.model)")
        }

        // 构建额外的请求头
        var additionalHeaders: [String: String] = [:]
        if config.providerId == "zhipu" {
            additionalHeaders["anthropic-version"] = "2023-06-01"
        }

        // 累积内容
        var accumulatedContent = ""
        var accumulatedToolCalls: [ToolCall] = []
        var streamError: String?

        // 工具调用参数累积（用于处理 input_json_delta 分片）
        var currentToolCallId: String?
        var currentToolCallName: String?
        var currentToolCallArguments = ""

        // 性能指标累积
        var inputTokens: Int?
        var outputTokens: Int?
        var stopReason: String?
        var timeToFirstToken: Double?
        var isFirstToken = true

        // 发送流式请求
        do {
            try await llmAPI.sendStreamingRequest(
                url: url,
                apiKey: config.apiKey,
                body: body,
                additionalHeaders: additionalHeaders
            ) { chunkData in
                do {
                    if let chunk = try provider.parseStreamChunk(data: chunkData) {
                        // 记录首 token 时间
                        if isFirstToken {
                            isFirstToken = false
                            let firstTokenTime = CFAbsoluteTimeGetCurrent()
                            timeToFirstToken = (firstTokenTime - startTime) * 1000.0
                            if Self.verbose {
                                os_log("\(self.t)⏱️ 首 token 延迟: \(String(format: "%.2f", timeToFirstToken!))ms")
                            }
                        }

                        // 累积内容 - 只累积 textDelta 的内容，跳过 thinkingDelta
                        if let content = chunk.content, chunk.eventType == .textDelta {
                            accumulatedContent += content
                            if Self.verbose && accumulatedContent.count < 200 {
                                os_log("\(self.t)📝 累积内容: \(content)")
                            }
                        }
                        
                        // 处理工具调用
                        if let toolCalls = chunk.toolCalls {
                            // 如果是新的工具调用，保存当前的（如果有）
                            if let currentId = currentToolCallId,
                               let currentName = currentToolCallName {
                                let toolCall = ToolCall(
                                    id: currentId,
                                    name: currentName,
                                    arguments: currentToolCallArguments.isEmpty ? "{}" : currentToolCallArguments
                                )
                                accumulatedToolCalls.append(toolCall)
                            }
                            
                            // 开始新的工具调用
                            if let firstToolCall = toolCalls.first {
                                currentToolCallId = firstToolCall.id
                                currentToolCallName = firstToolCall.name
                                currentToolCallArguments = ""
                            }
                        }
                        
                        // 处理工具调用参数分片
                        if let partialJson = chunk.partialJson {
                            currentToolCallArguments += partialJson
                        }
                        
                        if let error = chunk.error {
                            streamError = error
                        }

                        // 累积性能指标
                        if let tokens = chunk.inputTokens {
                            inputTokens = tokens
                        }
                        if let tokens = chunk.outputTokens {
                            outputTokens = tokens
                        }
                        if let reason = chunk.stopReason {
                            stopReason = reason
                        }

                        // 处理消息结束，保存最后一个工具调用
                        if chunk.isDone {
                            if let currentId = currentToolCallId,
                               let currentName = currentToolCallName {
                                let toolCall = ToolCall(
                                    id: currentId,
                                    name: currentName,
                                    arguments: currentToolCallArguments.isEmpty ? "{}" : currentToolCallArguments
                                )
                                accumulatedToolCalls.append(toolCall)
                            }
                        }

                        // 回调通知外部
                        onChunk(chunk)
                    } else {
                        // Provider 应该已经处理了所有事件类型，这里不应该再返回 nil
                        if Self.verbose {
                            let preview = String(data: chunkData, encoding: .utf8)?.prefix(100) ?? "无法解码"
                            os_log("\(self.t)⚠️ 警告：Provider 返回 nil，原始数据: \(preview)...")
                        }
                    }
                } catch {
                    if Self.verbose {
                        os_log("\(self.t)⚠️ 解析流式数据块失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            throw NSError(
                domain: "LLMService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
        
        // 流式结束后，保存最后一个工具调用
        if let currentId = currentToolCallId,
           let currentName = currentToolCallName {
            let toolCall = ToolCall(
                id: currentId,
                name: currentName,
                arguments: currentToolCallArguments.isEmpty ? "{}" : currentToolCallArguments
            )
            accumulatedToolCalls.append(toolCall)
        }

        // 检查流式过程中是否发生错误
        if let error = streamError {
            throw NSError(
                domain: "LLMService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: error]
            )
        }

        // 计算总耗时
        let endTime = CFAbsoluteTimeGetCurrent()
        let latency = (endTime - startTime) * 1000.0

        if Self.verbose {
            os_log("\(self.t)✅ 流式响应完成，总耗时：\(String(format: "%.2f", latency))ms, 内容长度：\(accumulatedContent.count)")
            if accumulatedContent.isEmpty {
                os_log("\(self.t)⚠️ 警告：累积内容为空！")
            } else {
                os_log("\(self.t)📝 累积内容预览：\(accumulatedContent.prefix(100))...")
            }
        }

        // 计算总 token 数
        let totalTokens: Int? = if let input = inputTokens, let output = outputTokens {
            input + output
        } else {
            nil
        }

        // 返回完整的助手消息（包含性能指标和请求参数）
        return ChatMessage(
            role: .assistant,
            content: accumulatedContent,
            toolCalls: accumulatedToolCalls.isEmpty ? nil : accumulatedToolCalls,
            providerId: config.providerId,
            modelName: config.model,
            latency: latency,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            timeToFirstToken: timeToFirstToken,
            finishReason: stopReason,
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}