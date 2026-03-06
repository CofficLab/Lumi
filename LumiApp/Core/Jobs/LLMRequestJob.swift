import Foundation
import MagicKit
import OSLog

/// LLM 请求任务
///
/// 负责在后台执行 LLM API 请求，避免阻塞主线程
/// 封装了完整的 LLM 请求流程，包括供应商选择、请求构建和响应解析
struct LLMRequestJob: SuperLog {
    /// 日志级别：0=禁用，1=基本，2=详细，3=调试
    nonisolated static let verbose: Int = 0
}

// MARK: - 任务参数

extension LLMRequestJob {
    /// 任务输入参数
    struct Input {
        /// 消息历史
        let messages: [ChatMessage]
        /// LLM 配置
        let config: LLMConfig
        /// 可用工具列表（对话模式下为空）
        let tools: [AgentTool]?
        /// 供应商注册表
        let registry: ProviderRegistry
    }

    /// 任务输出结果
    struct Output {
        /// AI 助手响应消息
        let response: ChatMessage
    }
}

// MARK: - 任务执行

extension LLMRequestJob {
    /// 执行 LLM 请求任务
    ///
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - config: LLM 配置
    ///   - tools: 可用工具列表
    ///   - registry: 供应商注册表
    /// - Returns: AI 助手的响应消息
    /// - Throws: 如果请求失败，抛出相应的错误
    static func run(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]?,
        registry: ProviderRegistry
    ) async throws -> ChatMessage {
        if Self.verbose >= 1 {
            os_log("\(Self.t)🚀 开始执行 LLM 请求任务")
        }

        guard !config.apiKey.isEmpty else {
            os_log(.error, "\(Self.t)❌ API Key 为空")
            throw NSError(
                domain: "LLMRequestJob",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "API Key is empty"]
            )
        }

        // 从注册表获取供应商实例
        // 注意：registry 是 @MainActor，需要在主线程调用
        guard let provider = registry.createProvider(id: config.providerId) else {
            os_log(.error, "\(Self.t)❌ 未找到供应商：\(config.providerId)")
            throw NSError(
                domain: "LLMRequestJob",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"]
            )
        }

        // 构建 URL
        guard let url = URL(string: provider.baseURL) else {
            os_log(.error, "\(Self.t)❌ 无效的 URL: \(provider.baseURL)")
            throw NSError(
                domain: "LLMRequestJob",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(provider.baseURL)"]
            )
        }

        // 构建请求体
        let body: [String: Any]
        do {
            body = try provider.buildRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: ""
            )
        } catch {
            os_log(.error, "\(Self.t)❌ 构建请求体失败：\(error.localizedDescription)")
            throw error
        }

        // 输出工具列表（调试用）
        if Self.verbose >= 2 {
            os_log("\(Self.t)🚀 发送请求到 \(config.providerId): \(config.model)")

            if let tools = tools, !tools.isEmpty {
                os_log("\(Self.t)📦 发送工具列表 (\(tools.count) 个):")
                for tool in tools {
                    os_log("\(Self.t)  - \(tool.name): \(tool.description.max(30))")
                }
            } else {
                os_log("\(Self.t)📦 无工具")
            }
        }

        // 构建请求头
        var additionalHeaders: [String: String] = [:]

        // 为 Anthropic 兼容的 API 添加 anthropic-version 请求头
        if config.providerId == "zhipu" {
            additionalHeaders["anthropic-version"] = "2023-06-01"
        }

        // 阿里云 Coding Plan 使用 Authorization: Bearer 认证
        let useBearerAuth = config.providerId == "aliyun"

        if Self.verbose >= 2 && !additionalHeaders.isEmpty {
            os_log("\(Self.t)📦 添加额外请求头：\(additionalHeaders)")
        }

        // 使用 LLM API 服务发送请求
        let llmAPI = LLMAPIService.shared
        let data: Data

        do {
            data = try await llmAPI.sendChatRequest(
                url: url,
                apiKey: config.apiKey,
                body: body,
                additionalHeaders: additionalHeaders,
                useBearerAuth: useBearerAuth
            )
        } catch let apiError as APIError {
            os_log(.error, "\(Self.t)❌ API 请求失败：\(apiError.localizedDescription)")
            throw NSError(
                domain: "LLMRequestJob",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: apiError.localizedDescription]
            )
        }

        // 解析响应
        let (content, toolCalls) = try provider.parseResponse(data: data)

        if Self.verbose >= 1 {
            os_log("\(Self.t)✅ 收到响应")
        }

        return ChatMessage(
        role: .assistant,
        content: content,
        toolCalls: toolCalls,
        providerId: config.providerId,
        modelName: config.model
    )
    }
}
