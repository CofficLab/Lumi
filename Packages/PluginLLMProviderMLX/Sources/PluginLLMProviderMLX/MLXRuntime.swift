import Foundation
import KitLLM
import MLXLLM
@preconcurrency import MLXLMCommon

@MainActor
final class MLXRuntime {
    static let shared = MLXRuntime()

    private var modelContainer: ModelContainer?
    private var currentModelID: String?

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
        currentModelID = nil
    }

    func generate(
        request: LLMRequest,
        modelID: String,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        guard isAppleSilicon else { throw MLXProviderError.unsupportedPlatform }
        try await ensureModelDownloaded(modelID)
        if currentModelID != modelID {
            modelContainer = nil
            let directory = MLXModelPaths.modelDirectory(for: modelID)
            do {
                // mlx-swift-lm 3.x 要求显式提供 TokenizerLoader（权重下载由 Lumi 自行管理，
                // 因此只需从本地目录加载权重与 tokenizer）。
                let tokenizerLoader: any TokenizerLoader = MLXTokenizerLoader()
                modelContainer = try await loadModelContainer(from: directory, using: tokenizerLoader)
            } catch {
                throw MLXProviderError.loadFailed(error.localizedDescription)
            }
            currentModelID = modelID
        }
        guard let container = modelContainer else { throw MLXProviderError.loadFailed("模型容器未就绪") }

        let lastUserImages = request.messages.last(where: { $0.role == .user })?.images ?? []
        let imageURLs = try lastUserImages.enumerated().map { index, image in
            let ext = image.mimeType.lowercased().contains("png") ? "png" : "jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("lumi-mlx-\(UUID().uuidString)-\(index)")
                .appendingPathExtension(ext)
            try image.data.write(to: url, options: .atomic)
            return url
        }
        defer { imageURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let lastUserMessageIndex = request.messages.lastIndex(where: { $0.role == .user })
        let messages = request.messages.enumerated().compactMap { index, message -> Chat.Message? in
            switch message.role {
            case .system: return .system(message.content)
            case .user:
                let images = index == lastUserMessageIndex ? imageURLs.map { UserInput.Image.url($0) } : []
                return images.isEmpty ? .user(message.content) : .user(message.content, images: images)
            case .assistant: return .assistant(message.content)
            default: return nil
            }
        }
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
        let stream = try await container.generate(
            input: prepared,
            parameters: GenerateParameters(temperature: 0.7),
            tools: tools
        )

        var content = ""
        var toolCalls: [LLMToolCall] = []
        for await result in stream {
            try Task.checkCancellation()
            if let text = result.chunk {
                content += text
                await onChunk(LLMStreamChunk(content: text, eventTitle: "生成中"))
            }
            if let toolCall = result.toolCall {
                let arguments = (try? JSONSerialization.data(withJSONObject: toolCall.function.arguments.mapValues { $0.anyValue }))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                let call = LLMToolCall(id: UUID().uuidString, name: toolCall.function.name, arguments: arguments)
                toolCalls.append(call)
                await onChunk(LLMStreamChunk(eventTitle: "工具调用", toolCalls: [call]))
            }
        }
        await onChunk(LLMStreamChunk(isDone: true, eventTitle: "结束"))
        return LLMResponse(content: content, model: modelID, toolCalls: toolCalls.isEmpty ? nil : toolCalls)
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

    private var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}
