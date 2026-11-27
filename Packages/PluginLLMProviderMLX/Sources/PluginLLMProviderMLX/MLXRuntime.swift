import Foundation
import KitLLM
import MLX
import MLXLLM
@preconcurrency import MLXLMCommon
import os

@MainActor
final class MLXRuntime {
    static let shared = MLXRuntime()

    private var modelContainer: ModelContainer?
    private var session = MLXModelSession()

    /// 交互式回合复用的会话。只保留最近一个：KV 缓存按整个上下文常驻，
    /// 同时保留多个会话会让内存成倍增长。
    private var chatSession: ChatSession?
    private var chatContinuation: MLXSessionContinuation?
    private var chatImages: MLXSessionImageStore?
    /// 是否有回合正在使用 `chatSession`。
    ///
    /// `generate` 是异步的，不同会话的回合可能交错进入；共享的会话不能
    /// 并发使用，占用期间后到的请求改走一次性会话。
    private var chatSessionBusy = false

    /// 与历史版本保持一致；`ChatSession` 在初始化时固定这组参数。
    private static let generationParameters = GenerateParameters(temperature: 0.7)

    /// 引用 VLM factory，确保 `MLXVLM` 目标被链接进二进制。
    ///
    /// 链接器会裁掉没有任何符号引用的目标，而 mlx-swift-lm 靠
    /// `NSClassFromString` 动态发现 factory——不显式引用的话 VLM factory
    /// 不会进二进制，VL 模型加载时会抛 `unsupportedModelType`。
    private static let vlmFactoryLinkage = MLXVLMFactoryLinkage.modelFactory

    func configure(rootDirectory: URL) {
        MLXModelPaths.configure(rootDirectory: rootDirectory)
        MLXDownloadManager.shared.configure(rootDirectory: rootDirectory)
    }

    func unload() {
        discardChatSession()
        modelContainer = nil
        session.discardContainer()
    }

    /// 指定模型当前是否已驻留内存。
    ///
    /// 与 `generate` 的加载判定同源：`session` 记录已成功加载的模型 ID，
    /// `modelContainer` 是容器是否在位，两者同时成立时下一次生成不会再
    /// 触发加载。发送链路的大模型确认门禁据此跳过已驻留模型。
    func isModelResident(modelID: String) -> Bool {
        !session.needsLoad(for: modelID) && modelContainer != nil
    }

    /// 执行一次生成。
    ///
    /// - Parameter reuseSession: 交互式回合传 `true`，允许复用上一轮的
    ///   KV 缓存；标题、摘要等辅助调用传 `false`，避免它们改写交互会话。
    func generate(
        request: LLMRequest,
        modelID: String,
        reuseSession: Bool,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        guard isAppleSilicon else { throw MLXProviderError.unsupportedPlatform }
        try await ensureModelDownloaded(modelID)
        if session.needsLoad(for: modelID) {
            discardChatSession()
            // 先丢容器（session 同步置空）：此后无论加载成败，状态都保持一致。
            // 加载失败时旧 ID 已被清空，重选原本可用的模型会重新走加载路径，
            // 不会跳过加载后撞上空容器守卫而无法恢复（#411）。
            modelContainer = nil
            session.discardContainer()
            let directory = MLXModelPaths.modelDirectory(for: modelID)
            do {
                modelContainer = try await Self.loadContainer(directory: directory)
            } catch let error as MLXError {
                throw MLXProviderError.loadFailed(Self.mlxMessage(error))
            } catch {
                throw MLXProviderError.loadFailed(error.localizedDescription)
            }
            session.didFinishLoad(modelID: modelID)
        }
        guard let container = modelContainer else { throw MLXProviderError.loadFailed("模型容器未就绪") }

        let messages = request.messages.filter(MLXChatMessages.isPromptMessage)
        guard !messages.isEmpty else { throw MLXProviderError.emptyPrompt }
        let tools = mlxTools(from: request.tools)
        let identity = MLXSessionContinuation.Identity(
            conversationID: request.conversationID,
            providerID: request.providerID,
            modelID: modelID,
            toolsSignature: Self.toolsSignature(of: tools)
        )

        do {
            if reuseSession, !chatSessionBusy,
                let chatSession, let chatImages, let continuation = chatContinuation,
                case .appendSuffix(let startIndex) = continuation.plan(for: messages, identity: identity) {
                return try await continueSession(
                    chatSession,
                    images: chatImages,
                    messages: messages,
                    startIndex: startIndex,
                    identity: identity,
                    modelID: modelID,
                    onChunk: onChunk
                )
            }

            return try await rebuildSession(
                container: container,
                messages: messages,
                tools: tools,
                identity: identity,
                reuseSession: reuseSession,
                modelID: modelID,
                onChunk: onChunk
            )
        } catch let error as MLXError {
            // MLX 在 C++ 层报错后容器内部状态不可信，丢弃让下次生成重新加载。
            unload()
            let message = Self.mlxMessage(error)
            MLXProviderPlugin.logger.error("MLX 生成失败，已释放模型容器：\(message, privacy: .public)")
            throw MLXProviderError.generationFailed(message)
        }
    }

    /// 只把新增消息追加进已有会话；命中缓存前缀的上下文不再重新 prefill。
    private func continueSession(
        _ chat: ChatSession,
        images: MLXSessionImageStore,
        messages: [LLMMessage],
        startIndex: Int,
        identity: MLXSessionContinuation.Identity,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        chatSessionBusy = true
        defer { chatSessionBusy = false }

        do {
            let suffix = Array(messages[startIndex...])
            let imageURLs = try images.makeImageURLs(messages: suffix[...], startingAt: startIndex)
            let chatMessages = MLXChatMessages.build(
                from: suffix,
                imageURLsByMessageIndex: imageURLs
            )
            let response = try await Self.stream(
                MLXSessionTurnBox(chat: chat, messages: chatMessages),
                modelID: modelID,
                onChunk: onChunk
            )
            chatContinuation = MLXSessionContinuation(
                identity: identity,
                consumedMessages: messages,
                lastAssistant: Self.assistantMessage(from: response)
            )
            return response
        } catch {
            // 会话状态已不可信（取消、报错、缓存账本不一致），丢弃后由下一轮重建。
            discardChatSession()
            throw error
        }
    }

    /// 用完整历史重建会话，执行一次全量 prefill。
    private func rebuildSession(
        container: ModelContainer,
        messages: [LLMMessage],
        tools: [[String: any Sendable]]?,
        identity: MLXSessionContinuation.Identity,
        reuseSession: Bool,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        // 只有交互式回合、且没有其他回合占用旧会话时才替换它；
        // 一次性调用（标题/摘要）不得改写交互会话。
        let ownsStoredSession = reuseSession && !chatSessionBusy
        if ownsStoredSession {
            // 旧会话不再匹配当前历史，先释放它的缓存再建新会话，
            // 避免两份缓存同时驻留。
            discardChatSession()
            chatSessionBusy = true
        }
        defer { if ownsStoredSession { chatSessionBusy = false } }

        let images = try MLXSessionImageStore.make()
        var keepImages = false
        defer { if !keepImages { images.remove() } }

        let imageURLs = try images.makeImageURLs(messages: messages[...], startingAt: 0)
        let chatMessages = MLXChatMessages.build(
            from: messages,
            imageURLsByMessageIndex: imageURLs
        )
        guard !chatMessages.isEmpty else { throw MLXProviderError.emptyPrompt }

        let chat = ChatSession(
            container,
            generateParameters: Self.generationParameters,
            // 默认的 512×512 缩放只在示例 App 中使用；这里保持模型自身配置。
            processing: UserInput.Processing(),
            tools: tools
        )
        let response = try await Self.stream(
            MLXSessionTurnBox(chat: chat, messages: chatMessages),
            modelID: modelID,
            onChunk: onChunk
        )
        if ownsStoredSession {
            chatSession = chat
            chatContinuation = MLXSessionContinuation(
                identity: identity,
                consumedMessages: messages,
                lastAssistant: Self.assistantMessage(from: response)
            )
            chatImages = images
            keepImages = true
        }
        return response
    }

    /// 在 MainActor 之外消费生成流：MLX 的 `withError` 闭包不能被主 actor 发送。
    ///
    /// `ChatSession` 与提示词都不是 Sendable，不能直接捕获进 `withError`
    /// 的非隔离闭包；这里用一次性盒子把本轮会话与提示词恰好移交一次
    /// （与 mlx-swift-lm 内部的 `SendableBox` 同一手法）。会话的并发使用
    /// 由 `chatSessionBusy` 保证不会发生。
    private nonisolated static func stream(
        _ turn: MLXSessionTurnBox,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        try await withError { mlxError in
            var consumer = MLXGenerationConsumer()
            for try await result in turn.chat.streamDetails(to: turn.messages) {
                try Task.checkCancellation()
                // 一旦 MLX 报错，后续 token 都建立在校验失败的计算图上，立即止损。
                try mlxError.check()
                await consumer.consume(result, onChunk: onChunk)
            }
            try mlxError.check()
            // 拒绝事件不作为正文输出；静默丢弃会落入通用空响应重试（#1228）。
            // 抛带安全诊断的错误，AgentLoopFailure 归为 unknown，不自动重试。
            if let rejection = consumer.rejection {
                throw MLXProviderError.rejectedToolCall(rejection)
            }
            await onChunk(LLMStreamChunk(isDone: true, eventTitle: "结束"))
            return consumer.response(model: modelID)
        }
    }

    private func discardChatSession() {
        chatImages?.remove()
        chatImages = nil
        chatContinuation = nil
        chatSession = nil
    }

    private nonisolated static func loadContainer(directory: URL) async throws -> ModelContainer {
        // mlx-swift-lm 3.x 要求显式提供 TokenizerLoader（权重下载由 Lumi 自行管理，
        // 因此只需从本地目录加载权重与 tokenizer）。
        let tokenizerLoader: any TokenizerLoader = MLXTokenizerLoader()
        return try await withError { _ in
            try await loadModelContainer(from: directory, using: tokenizerLoader)
        }
    }

    private func mlxTools(from tools: [LLMFunctionSchema]?) -> [[String: any Sendable]]? {
        guard let tools, !tools.isEmpty else { return nil }
        return tools.map { tool in
            let function: [String: any Sendable] = [
                "name": tool.name,
                "description": tool.description,
                "parameters": MLXSendableJSON.convertSendableDictionary(tool.parameters),
            ]
            let entry: [String: any Sendable] = [
                "type": "function",
                "function": function,
            ]
            return entry
        }
    }

    /// 工具定义的稳定签名：工具集合变化时必须重建会话，因为提示词里的
    /// 工具段随之变化，旧 KV 缓存不再对应同一提示词。
    private static func toolsSignature(of tools: [[String: any Sendable]]?) -> String {
        guard let tools, !tools.isEmpty else { return "" }
        guard let data = try? JSONSerialization.data(withJSONObject: tools, options: [.sortedKeys]) else {
            return String(describing: tools)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func assistantMessage(from response: LLMResponse) -> LLMMessage {
        LLMMessage(role: .assistant, content: response.content, toolCalls: response.toolCalls)
    }

    private func ensureModelDownloaded(_ modelID: String) async throws {
        let directory = MLXModelPaths.modelDirectory(for: modelID)
        if MLXModelDownloader.isComplete(directory: directory) {
            return
        }
        await MLXDownloadManager.shared.download(modelID: modelID)
        guard MLXModelDownloader.isComplete(directory: MLXModelPaths.modelDirectory(for: modelID)) else {
            throw MLXProviderError.downloadFailed("模型下载未完成")
        }
    }

    private static func mlxMessage(_ error: MLXError) -> String {
        switch error {
        case .caught(let detail): return detail
        }
    }

    private var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}

/// 把非 Sendable 的会话与提示词带进 `withError` 非隔离闭包的一次性盒子。
///
/// 只在单线程接力中使用：`generate` 在 MainActor 上构造并交出，生成流在
/// `stream` 内顺序消费；取用期间不会有第二个调用方同时持有该会话。
private final class MLXSessionTurnBox: @unchecked Sendable {
    let chat: ChatSession
    let messages: [Chat.Message]

    init(chat: ChatSession, messages: [Chat.Message]) {
        self.chat = chat
        self.messages = messages
    }
}