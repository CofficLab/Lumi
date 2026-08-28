import Foundation
import KitLLM
import MLXLLM
@preconcurrency import MLXLMCommon

@MainActor
final class MLXRuntime {
    static let shared = MLXRuntime()

    private var modelContainer: ModelContainer?
    private var currentModelID: String?

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
            let configuration = ModelConfiguration(directory: MLXModelPaths.modelDirectory(for: modelID))
            do {
                modelContainer = try await loadModelContainer(configuration: configuration) { _ in }
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
        let input = UserInput(chat: messages, tools: mlxTools(from: request.tools))
        let prepared = try await container.prepare(input: input)
        let stream = try await container.generate(input: prepared, parameters: GenerateParameters(temperature: 0.7))

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

    private func mlxTools(from tools: [LLMFunctionSchema]?) -> [[String: Sendable]]? {
        guard let tools, !tools.isEmpty else { return nil }
        return tools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": sendableJSON(tool.parameters),
                ],
            ]
        }
    }

    private func sendableJSON(_ value: Any) -> any Sendable {
        switch value {
        case let value as String: return value
        case let value as Bool: return value
        case let value as Int: return value
        case let value as Double: return value
        case let value as [Any]: return value.map(sendableJSON)
        case let value as [String: Any]: return value.mapValues(sendableJSON)
        default: return String(describing: value)
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
