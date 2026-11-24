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
        modelContainer = nil
        session.discardContainer()
    }

    func generate(
        request: LLMRequest,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        guard isAppleSilicon else { throw MLXProviderError.unsupportedPlatform }
        try await ensureModelDownloaded(modelID)
        if session.needsLoad(for: modelID) {
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

        // 每条 user 消息的图片都写成临时文件并按消息位置传入（#412）：
        // 只保留最后一条的图片会让多轮对话的历史图像全部丢失。
        var imageFiles: [URL] = []
        var imageURLsByMessageIndex: [Int: [URL]] = [:]
        defer { imageFiles.forEach { try? FileManager.default.removeItem(at: $0) } }
        for (index, message) in request.messages.enumerated() where message.role == .user {
            let urls = try message.images.enumerated().map { imageIndex, image in
                let ext = image.mimeType.lowercased().contains("png") ? "png" : "jpg"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("lumi-mlx-\(UUID().uuidString)-\(index)-\(imageIndex)")
                    .appendingPathExtension(ext)
                try image.data.write(to: url, options: .atomic)
                return url
            }
            if !urls.isEmpty {
                imageURLsByMessageIndex[index] = urls
                imageFiles.append(contentsOf: urls)
            }
        }

        let messages = MLXChatMessages.build(
            from: request.messages,
            imageURLsByMessageIndex: imageURLsByMessageIndex
        )
        guard !messages.isEmpty else { throw MLXProviderError.emptyPrompt }
        let tools = mlxTools(from: request.tools)
        let input = UserInput(chat: messages, tools: tools)
        let prepared = try await container.prepare(input: input)
        // `generate(..., tools:)` 与 `UserInput.tools` 用途不同，**都要传**：
        // - `UserInput.tools` 供 chat template 渲染提示词；
        // - `generate(..., tools:)` 供响应解析层做参数类型解析与函数名授权。
        //
        // 省略后者时它的默认值是 `nil`，语义是「接受任意解析出的函数名，
        // 且不做 Schema 类型转换」：声明为 `integer` 的参数保持字符串，
        // 未声明的函数名也不会被拒绝——错误的参数类型会直接流进 Agent
        // 工具链。
        do {
            return try await Self.streamGeneration(
                container: container,
                prepared: prepared,
                tools: tools,
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

    /// 在 MainActor 之外执行生成：MLX 的 `withError` 是 `@concurrent`，从
    /// 主 actor 调用会把非 Sendable 的 `LMInput` 连同闭包一起判为跨域发送。
    private nonisolated static func streamGeneration(
        container: ModelContainer,
        prepared: sending LMInput,
        tools: [[String: any Sendable]]?,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        try await withError { mlxError in
            let stream = try await container.generate(
                input: consume prepared,
                parameters: GenerateParameters(temperature: 0.7),
                tools: tools
            )

            var consumer = MLXGenerationConsumer()
            for await result in stream {
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
