import Combine
import SwiftUI
import Foundation
import MagicKit

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
    nonisolated static let verbose = 2

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
        let registry = ProviderRegistry()
        // 通过 LLM 插件系统自动发现并注册所有可用供应商
        LLMPluginsVM.registerAllProviders(to: registry)
        self.registry = registry
        self.llmAPI = LLMAPIService()
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)LLM 服务已初始化")
        }
    }
    
    /// 将原始 SSE 数据块拆分为单事件列表。
    /// 兼容“多个 event/data 粘在同一个网络块中、且缺少空行分隔”的非标准实现。
    private nonisolated static func splitSSEEvents(from rawData: Data) -> [Data] {
        guard let text = String(data: rawData, encoding: .utf8) else {
            return [rawData]
        }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var events: [Data] = []
        var currentLines: [String] = []
        var hasDataLine = false

        func flushCurrentEvent() {
            guard !currentLines.isEmpty else { return }
            let payload = currentLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !payload.isEmpty, let data = payload.data(using: .utf8) {
                events.append(data)
            }
            currentLines.removeAll(keepingCapacity: true)
            hasDataLine = false
        }

        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty {
                flushCurrentEvent()
                continue
            }
            if line.hasPrefix("event:"), hasDataLine {
                flushCurrentEvent()
            }
            if line.hasPrefix("data:") {
                hasDataLine = true
            }
            currentLines.append(line)
        }

        flushCurrentEvent()
        return events.isEmpty ? [rawData] : events
    }

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
    private func ensureLocalModelReady(
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
                try Task.checkCancellation()
                state = await local.getModelState()
                if state == .ready { return }
                if case .error = state { break }
                try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
            }
            if state != .ready {
                throw NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "加载超时，请稍后重试或到设置中查看"])
            }
            return
        }

        do {
            try await local.loadModel(id: modelId)
        } catch {
            throw NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        }

        state = await local.getModelState()
        if state != .ready {
            let msg: String
            if case .error(let s) = state { msg = s } else { msg = "模型未就绪" }
            throw NSError(domain: "LLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: msg])
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
        // 记录开始时间，用于计算延迟
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从注册表获取供应商实例（先取 provider，本地供应商不校验 API Key）
        guard let provider = registry.createProvider(id: config.providerId) else {
            AppLogger.core.error("\(self.t)未找到供应商：\(config.providerId)")
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"])
        }

        // 仅远程供应商需要校验 API Key；本地供应商无需 API Key
        let isLocal = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocal {
            do {
                try config.validate()
            } catch {
                AppLogger.core.error("\(self.t)配置校验失败：\(error.localizedDescription)")
                throw error
            }
        }

        // 本地供应商：走 sendMessage，不经过 HTTP
        if let local = provider as? any SuperLocalLLMProvider {
            try await ensureLocalModelReady(local: local, modelId: config.model)
            let images = messages.last(where: { $0.role == .user }).map(\.images) ?? []
            let msg = try await local.sendMessage(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: nil,
                images: images
            )
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            Task.detached(priority: .utility) {
                LLMRequestLoggerCenter.shared.log(
                    providerId: config.providerId,
                    model: config.model,
                    url: URL(string: "file:///local")!,
                    method: "POST",
                    statusCode: nil,
                    durationMs: latency,
                    requestBody: nil,
                    responseBody: nil,
                    error: nil
                )
            }
            return msg
        }

        // 构建 API URL（远程供应商）
        let baseURLString = provider.baseURL
        AppLogger.core.info("\(self.t)构建 API URL：\(baseURLString)")
        guard let url = URL(string: baseURLString) else {
            AppLogger.core.error("\(self.t)无效的 URL: \(baseURLString)")
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(baseURLString)"])
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
            AppLogger.core.error("\(self.t)构建请求体失败：\(error.localizedDescription)")
            throw error
        }

        // 输出调试信息
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)发送请求到 \(config.providerId): \(config.model)")

            if let tools = tools, !tools.isEmpty {
                AppLogger.core.info("\(self.t)发送工具列表 (\(tools.count) 个):")
                for tool in tools {
                    AppLogger.core.info("\(self.t)  - \(tool.name): \(tool.description)")
                }
            } else {
                AppLogger.core.info("\(self.t)无工具")
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

            if Self.verbose >= 1 && !additionalHeaders.isEmpty {
                AppLogger.core.info("\(self.t)添加额外请求头：\(additionalHeaders)")
            }

            // 发送聊天请求
            let data: Data
            do {
                data = try await llmAPI.sendChatRequest(
                    url: url,
                    apiKey: config.apiKey,
                    body: body,
                    additionalHeaders: additionalHeaders
                )
            } catch {
                // 记录失败请求日志（通过内核级 LoggerCenter，若未注册实现则为 no-op）
                Task.detached(priority: .utility) {
                    LLMRequestLoggerCenter.shared.log(
                        providerId: config.providerId,
                        model: config.model,
                        url: url,
                        method: "POST",
                        statusCode: nil,
                        durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
                        requestBody: try? JSONSerialization.data(withJSONObject: body),
                        responseBody: nil,
                        error: error
                    )
                }
                throw error
            }

            // 解析响应
            let (content, toolCalls) = try provider.parseResponse(data: data)

            // 计算总耗时（毫秒）
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000.0

            // 记录成功请求日志（不阻塞主调用链）
            Task.detached(priority: .utility) {
                LLMRequestLoggerCenter.shared.log(
                    providerId: config.providerId,
                    model: config.model,
                    url: url,
                    method: "POST",
                    statusCode: 200, // 目前由 LLMAPIService 校验 2xx，否则抛错
                    durationMs: latency,
                    requestBody: try? JSONSerialization.data(withJSONObject: body),
                    responseBody: data,
                    error: nil
                )
            }

            // 输出响应信息
            if Self.verbose >= 1 {
                if let toolCalls = toolCalls, !toolCalls.isEmpty {
                    AppLogger.core.info("\(self.t)收到响应：\(content.prefix(10))...，包含 \(toolCalls.count) 个工具调用，耗时：\(String(format: "%.2f", latency))ms")
                } else {
                    AppLogger.core.info("\(self.t)收到响应：「\(content.prefix(10))...」，耗时：\(String(format: "%.2f", latency))ms")
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
        onChunk: @Sendable @escaping (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        // 记录开始时间
        let startTime = CFAbsoluteTimeGetCurrent()

        // 从注册表获取供应商实例（先取 provider，本地供应商不校验 API Key）
        guard let provider = registry.createProvider(id: config.providerId) else {
            AppLogger.core.error("\(self.t)未找到供应商：\(config.providerId)")
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"])
        }

        // 仅远程供应商需要校验 API Key；本地供应商无需 API Key
        let isLocalStream = (provider as? any SuperLocalLLMProvider) != nil
        if !isLocalStream {
            do {
                try config.validate()
            } catch {
                AppLogger.core.error("\(self.t)配置校验失败：\(error.localizedDescription)")
                throw error
            }
        }

        // 本地供应商：走 streamChat，不经过 HTTP
        if let local = provider as? any SuperLocalLLMProvider {
            try await ensureLocalModelReady(local: local, modelId: config.model)
            let images = messages.last(where: { $0.role == .user }).map(\.images) ?? []
            let msg = try await local.streamChat(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: nil,
                images: images,
                onChunk: onChunk
            )
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            Task.detached(priority: .utility) {
                LLMRequestLoggerCenter.shared.log(
                    providerId: config.providerId,
                    model: config.model,
                    url: URL(string: "file:///local")!,
                    method: "local",
                    statusCode: nil,
                    durationMs: latency,
                    requestBody: nil,
                    responseBody: nil,
                    error: nil
                )
            }
            return msg
        }

        // 构建 API URL（远程供应商）
        let baseURLString = provider.baseURL
        
        guard let url = URL(string: baseURLString) else {
            AppLogger.core.error("\(self.t)无效的 URL: \(baseURLString)")
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(baseURLString)"])
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
            AppLogger.core.error("\(self.t)构建流式请求体失败：\(error.localizedDescription)")
            throw error
        }

        // 输出调试信息
        if Self.verbose >= 1 {
            AppLogger.core.info("\(self.t)发送流式请求到 \(config.providerId): \(config.model)")
        }

        // 构建额外的请求头
        var additionalHeaders: [String: String] = [:]
        if config.providerId == "zhipu" {
            additionalHeaders["anthropic-version"] = "2023-06-01"
        }

        // 使用 actor 来保护可变状态，确保在闭包中的修改对外部可见
        actor StreamingState {
            var accumulatedContentChunks: [String] = []
            var accumulatedContentLength: Int = 0
            var accumulatedToolCalls: [ToolCall] = []
            var streamError: String?
            var currentToolCallId: String?
            var currentToolCallName: String?
            var currentToolCallArgumentChunks: [String] = []
            var inputTokens: Int?
            var outputTokens: Int?
            var stopReason: String?
            var timeToFirstToken: Double?
            var isFirstToken = true
            let startTime: CFAbsoluteTime
            
            init(startTime: CFAbsoluteTime) {
                self.startTime = startTime
            }
            
            func recordFirstToken() -> Double? {
                guard isFirstToken else { return nil }
                isFirstToken = false
                let firstTokenTime = CFAbsoluteTimeGetCurrent()
                let ttft = (firstTokenTime - startTime) * 1000.0
                timeToFirstToken = ttft
                return ttft
            }
            
            func appendContent(_ content: String) {
                accumulatedContentChunks.append(content)
                accumulatedContentLength += content.count
            }
            
            func startNewToolCall(_ toolCall: ToolCall, hasPartialJson: Bool = false) {
                currentToolCallId = toolCall.id
                currentToolCallName = toolCall.name
                // 如果工具调用已经有完整的参数，且后续不会有 partialJson，则直接使用
                // 否则，清空累积器，等待后续的 partialJson 累积
                if !hasPartialJson && !toolCall.arguments.isEmpty && toolCall.arguments != "{}" {
                    // 已经有完整参数，设置累积器为当前参数（不再累积）
                    currentToolCallArgumentChunks = [toolCall.arguments]
                } else {
                    currentToolCallArgumentChunks = []
                }
            }

            /// 完成当前工具调用，使用累积的参数或预设的参数
            func finalizeCurrentToolCall() -> ToolCall? {
                guard let currentId = currentToolCallId,
                      let currentName = currentToolCallName else {
                    return nil
                }
                let arguments: String
                if currentToolCallArgumentChunks.isEmpty {
                    arguments = "{}"
                } else if currentToolCallArgumentChunks.count == 1 {
                    // 只有一个分片，直接使用
                    arguments = currentToolCallArgumentChunks[0]
                } else {
                    // 多个分片，需要合并
                    arguments = currentToolCallArgumentChunks.joined()
                }
                return ToolCall(id: currentId, name: currentName, arguments: arguments)
            }

            func saveCurrentToolCall() {
                if let toolCall = finalizeCurrentToolCall() {
                    accumulatedToolCalls.append(toolCall)
                    // 清空当前状态，避免重复保存
                    currentToolCallId = nil
                    currentToolCallName = nil
                    currentToolCallArgumentChunks = []
                }
            }
            
            func appendToolCallArguments(_ partialJson: String) {
                currentToolCallArgumentChunks.append(partialJson)
            }
            
            func setError(_ error: String) {
                streamError = error
            }
            
            func updateTokens(input: Int?, output: Int?) {
                if let input = input { inputTokens = input }
                if let output = output { outputTokens = output }
            }
            
            func setStopReason(_ reason: String) {
                stopReason = reason
            }
        }
        
        let state = StreamingState(startTime: startTime)

        // 发送流式请求
        do {
            try await llmAPI.sendStreamingRequest(
                url: url,
                apiKey: config.apiKey,
                body: body,
                additionalHeaders: additionalHeaders
            ) { chunkData in
                do {
                    try Task.checkCancellation()
                    var shouldContinue = true
                    let parseWarnThreshold: Double = 0.3
                    let callbackWarnThreshold: Double = 0.3

                    for eventData in Self.splitSSEEvents(from: chunkData) {
                        let parseStart = CFAbsoluteTimeGetCurrent()
                        if let chunk = try provider.parseStreamChunk(data: eventData) {
                            let parseElapsed = CFAbsoluteTimeGetCurrent() - parseStart
                            if parseElapsed > parseWarnThreshold {
                                AppLogger.core.error("\(self.t)parseStreamChunk 耗时异常: \(String(format: "%.3f", parseElapsed))s, bytes=\(eventData.count)")
                            }
                            // 记录首 token 时间
                            if let ttft = await state.recordFirstToken(), Self.verbose >= 1 {
                                let ttftStr = ttft >= 1000 ? String(format: "%.2fs", ttft / 1000) : String(format: "%.2fms", ttft)
                                AppLogger.core.info("\(self.t)首 token 延迟: \(ttftStr)")
                            }

                            // 累积内容 - 只累积 textDelta 的内容，跳过 thinkingDelta
                            if let content = chunk.content, chunk.eventType == .textDelta {
                                await state.appendContent(content)
                            }

                            // 处理工具调用
                            if let toolCalls = chunk.toolCalls {
                                // 如果是新的工具调用，保存当前的（如果有）
                                await state.saveCurrentToolCall()

                                // 开始新的工具调用
                                if let firstToolCall = toolCalls.first {
                                    // 如果同时有 partialJson，说明参数还需要后续累积
                                    let hasPartialJson = chunk.partialJson != nil
                                    await state.startNewToolCall(firstToolCall, hasPartialJson: hasPartialJson)
                                }
                            }

                            // 处理工具调用参数分片
                            if let partialJson = chunk.partialJson {
                                await state.appendToolCallArguments(partialJson)
                            }

                            if let error = chunk.error {
                                await state.setError(error)
                            }

                            // 累积性能指标
                            await state.updateTokens(input: chunk.inputTokens, output: chunk.outputTokens)
                            if let reason = chunk.stopReason {
                                await state.setStopReason(reason)
                            }

                            // 处理消息结束，保存最后一个工具调用
                            if chunk.isDone {
                                await state.saveCurrentToolCall()
                            }

                            // 回调通知外部
                            let callbackStart = CFAbsoluteTimeGetCurrent()
                            let eventTypeRaw = chunk.eventType?.rawValue ?? "unknown"
                            let hangWatchdog = Task.detached(priority: .utility) {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                guard !Task.isCancelled else { return }
                                AppLogger.core.error("\(self.t)onChunk(业务回调)疑似卡住(>2s): event=\(eventTypeRaw)")
                            }
                            await onChunk(chunk)
                            hangWatchdog.cancel()
                            let callbackElapsed = CFAbsoluteTimeGetCurrent() - callbackStart
                            if callbackElapsed > callbackWarnThreshold {
                                AppLogger.core.error("⏱️ onChunk(业务回调)耗时异常: \(String(format: "%.3f", callbackElapsed))s, event=\(chunk.eventType?.rawValue ?? "unknown")")
                            }

                            if chunk.isDone {
                                shouldContinue = false
                                break
                            }
                        } else if Self.verbose >= 1 {
                            // Provider 应该已经处理了所有事件类型，这里不应该再返回 nil
                            let preview = String(data: eventData, encoding: .utf8)?.prefix(100) ?? "无法解码"
                            AppLogger.core.warning("\(self.t)警告：Provider 返回 nil，原始数据: \(preview)...")
                        }
                    }
                    return shouldContinue
                } catch {
                    if Self.verbose >= 1 {
                        AppLogger.core.warning("\(self.t)解析流式数据块失败: \(error.localizedDescription)")
                    }
                    return true
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
        await state.saveCurrentToolCall()

        // 检查流式过程中是否发生错误
        if let error = await state.streamError {
            throw NSError(
                domain: "LLMService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: error]
            )
        }

        // 计算总耗时
        let endTime = CFAbsoluteTimeGetCurrent()
        let latency = (endTime - startTime) * 1000.0

        // 记录流式请求日志（仅记录元数据，不聚合响应体）
        Task.detached(priority: .utility) {
            LLMRequestLoggerCenter.shared.log(
                providerId: config.providerId,
                model: config.model,
                url: url,
                method: "POST",
                statusCode: nil,
                durationMs: latency,
                requestBody: try? JSONSerialization.data(withJSONObject: body),
                responseBody: nil,
                error: nil
            )
        }

        // 获取最终状态
        let finalContent = await state.accumulatedContentChunks.joined()
        let finalToolCalls = await state.accumulatedToolCalls
        let finalInputTokens = await state.inputTokens
        let finalOutputTokens = await state.outputTokens
        let finalStopReason = await state.stopReason
        let finalTimeToFirstToken = await state.timeToFirstToken

        if Self.verbose >= 1 {
            AppLogger.core.info("\(Self.t)✅ 流式响应完成，总耗时：\(String(format: "%.2f", latency))ms, TTFT: \(String(format: "%.2f", finalTimeToFirstToken ?? 0))ms, 内容长度：\(finalContent.count)")
        }

        // 计算总 token 数
        let totalTokens: Int? = if let input = finalInputTokens, let output = finalOutputTokens {
            input + output
        } else {
            nil
        }

        // 返回完整的助手消息（包含性能指标和请求参数）
        return ChatMessage(
            role: .assistant,
            content: finalContent,
            toolCalls: finalToolCalls.isEmpty ? nil : finalToolCalls,
            providerId: config.providerId,
            modelName: config.model,
            latency: latency,
            inputTokens: finalInputTokens,
            outputTokens: finalOutputTokens,
            totalTokens: totalTokens,
            timeToFirstToken: finalTimeToFirstToken,
            finishReason: finalStopReason,
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
