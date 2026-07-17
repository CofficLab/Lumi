import AgentToolKit
import Foundation
import HttpKit
import KeychainKit
import LLMKit
import LumiCoreKit
import LumiLLMProviderSupport
import SuperLogKit
import os

public final class CodexProvider: NSObject, SuperLLMProvider, SuperLocalLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🔮"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.codex")

    public static let id = "codex"
    public static let displayName = LumiPluginLocalization.string("Codex", bundle: .module)
    public static let shortName = "CX"
    public static let description = LumiPluginLocalization.string("通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）", bundle: .module)
    public static let websiteURL: String? = "https://github.com/openai/codex"
    public static let apiKeyStorageKey = ""

    public func lumiResolveAPIKey() throws -> String {
        let key = KeychainStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public static let defaultModel = "gpt-5.5"

    public static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", description: LumiPluginLocalization.string("GPT-5.5，Codex 当前旗舰模型", bundle: .module), spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-5.4-mini", description: LumiPluginLocalization.string("GPT-5.4 Mini，轻量快速模型", bundle: .module), spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
    ]

    private let cli: CodexCLI

    public required override convenience init() {
        self.init(cli: CodexCLI())
    }

    init(cli: CodexCLI) {
        self.cli = cli
        super.init()
    }

    public var baseURL: String { "" }

    public func buildRequest(url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    public func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式，请使用 sendMessage 或 streamChat")
    }

    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式")
    }

    public func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式")
    }

    public func parseStreamChunk(data: Data) throws -> StreamChunk? {
        nil
    }

    public func streamChat(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment],
        onChunk: @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        let result = try await sendMessage(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            images: images
        )

        for chunk in splitIntoChunks(text: result.content, chunkSize: 4) {
            await onChunk(StreamChunk(content: chunk, eventType: .textDelta))
        }

        await onChunk(StreamChunk(
            content: nil,
            isDone: true,
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens
        ))

        return result
    }

    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment]
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard cli.isAvailable else {
            throw CodexError.cliNotFound(cli.executablePath)
        }

        let prompt = Self.buildPrompt(from: messages, systemPrompt: systemPrompt ?? "")

        if Self.verbose {
            Self.logger.info("\(self.t)执行 codex -a never exec --json -m \(model) --skip-git-repo-check")
        }

        let output = try await runCodexProcess(prompt: prompt, model: model)
        let parsed = CodexOutputParser.parse(output)

        guard !parsed.agentMessages.isEmpty else {
            if let firstError = parsed.errors.first {
                throw CodexError.executionFailed(firstError)
            }
            if let firstLine = parsed.nonJSONLines.first {
                throw CodexError.executionFailed(firstLine)
            }
            throw CodexError.emptyResponse
        }

        let finalContent = parsed.agentMessages.joined(separator: "\n\n")
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            providerId: Self.id,
            modelName: model,
            latency: latency,
            inputTokens: parsed.inputTokens,
            outputTokens: parsed.outputTokens,
            totalTokens: (parsed.inputTokens ?? 0) + (parsed.outputTokens ?? 0)
        )
    }

    public func getAvailableModels() async -> [LocalModelInfo] {
        Self.modelCatalog.map { item in
            LocalModelInfo(
                id: item.id,
                displayName: item.id,
                description: item.description,
                size: "CLI",
                minRAM: 0,
                expectedBytes: 0,
                supportsVision: item.spec.capabilities.supportsVision,
                supportsTools: item.spec.capabilities.supportsTools
            )
        }
    }

    public func getCachedModels() async -> Set<String> {
        Set(Self.modelCatalog.map(\.id))
    }

    public func downloadModel(id: String) async throws {}
    public func loadModel(id: String) async throws {}
    public func unloadModel() async {}
    public func getDownloadStatus() -> LocalDownloadStatus { .completed }

    public func getModelState() async -> LocalLLMState {
        cli.isAvailable ? .ready : .error("未找到 codex CLI: \(cli.executablePath)")
    }

    public func getLoadedModelId() async -> String? { nil }
    public func getCacheDirectoryURL() -> URL { FileManager.default.temporaryDirectory }

    public func displayName(forModelId modelId: String) -> String? {
        Self.modelCatalog.first(where: { $0.id == modelId })?.description
    }


    // MARK: - Transport

    public func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await LocalLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            onChunk: onChunk
        )
    }

    public func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await LocalLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    public func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }

    public static func isCodexAvailable() -> Bool {
        CodexCLI().isAvailable
    }

    public static func codexPath() -> String {
        CodexCLI.defaultExecutablePath()
    }

    static func buildPrompt(from messages: [ChatMessage], systemPrompt: String) -> String {
        var parts: [String] = []

        if !systemPrompt.isEmpty {
            parts.append("[System] \(systemPrompt)")
        }

        for message in messages {
            guard message.shouldSendToLLM else { continue }

            switch message.role {
            case .system:
                parts.append("[System] \(message.content)")
            case .user:
                if let toolCallID = message.toolCallID {
                    parts.append("[Tool Result \(toolCallID)] \(message.content)")
                } else {
                    parts.append("[User] \(message.content)")
                }
            case .assistant:
                var text = message.content
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    let callsDesc = toolCalls.map { "\($0.name)(\($0.arguments))" }.joined(separator: "; ")
                    text = text.isEmpty ? "[Tool Calls: \(callsDesc)]" : "\(text)\n[Tool Calls: \(callsDesc)]"
                }
                if !text.isEmpty {
                    parts.append("[Assistant] \(text)")
                }
            case .tool:
                parts.append("[Tool] \(message.content)")
            case .status, .error, .unknown:
                break
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private func runCodexProcess(prompt: String, model: String) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: cli.executablePath)
        process.arguments = cli.arguments(prompt: prompt, model: model)
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputBuffer = CodexProcessOutputBuffer()
        let errorBuffer = CodexProcessOutputBuffer()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputBuffer.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorBuffer.append(handle.availableData)
        }

        if Self.verbose {
            let preview = String(prompt.prefix(80))
            Self.logger.info("\(self.t)启动: codex -a never exec --json -m \(model) --skip-git-repo-check \"\(preview)...\"")
        }

        do {
            try process.run()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                outputBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
                errorBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

                let output = String(data: outputBuffer.data(), encoding: .utf8) ?? ""
                let stderr = String(data: errorBuffer.data(), encoding: .utf8) ?? ""
                let combined = [output, stderr].filter { !$0.isEmpty }.joined(separator: "\n")

                if process.terminationStatus != 0 {
                    let parsed = CodexOutputParser.parse(combined)
                    let message = parsed.errors.first ?? parsed.nonJSONLines.first ?? "codex exec 退出码: \(process.terminationStatus)"
                    continuation.resume(throwing: CodexError.executionFailed(message))
                } else {
                    continuation.resume(returning: combined)
                }
            }
        }
    }

    private func splitIntoChunks(text: String, chunkSize: Int) -> [String] {
        guard chunkSize > 0 else { return [text] }
        var chunks: [String] = []
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return chunks
    }
}

private final class CodexProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

public enum CodexError: LocalizedError, Equatable {
    case cliNotFound(String)
    case notSupported(String)
    case executionFailed(String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .cliNotFound(let path):
            return "未找到 codex CLI，请确认已安装 codex。检测路径：\(path)"
        case .notSupported(let msg):
            return "不支持的操作：\(msg)"
        case .executionFailed(let msg):
            return "Codex 执行失败：\(msg)"
        case .emptyResponse:
            return "Codex 返回了空响应"
        }
    }
}
