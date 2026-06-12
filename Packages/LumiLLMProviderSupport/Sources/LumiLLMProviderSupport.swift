import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
import LumiCoreKit

public typealias LumiOpenAICompatibleProviderConfiguration = OpenAICompatibleProviderConfiguration
public typealias LumiAnthropicCompatibleProviderConfiguration = AnthropicCompatibleProviderConfiguration

private enum LumiLLMRequestMessages {
    static func preparedForProvider(_ request: LumiLLMRequest) -> [LLMProviderKit.ChatMessage] {
        LumiVisionMessageSupport.preparedMessages(for: request)
    }
}

open class OpenAICompatibleLumiProvider: LumiLLMProvider, @unchecked Sendable {
    open class var info: LumiLLMProviderInfo {
        fatalError("Subclasses must override info")
    }

    open class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_\(info.id)"
    }

    open class var environmentAPIKeyName: String? {
        nil
    }

    private let apiService: LLMAPIService
    private let adapter: OpenAICompatibleProviderAdapter

    public init(
        configuration: OpenAICompatibleProviderConfiguration,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        self.apiService = apiService
        self.adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
    }

    open func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }

        guard let url = URL(string: adapter.configuration.baseURL) else {
            throw LumiLLMProviderSupportError.invalidBaseURL(adapter.configuration.baseURL)
        }

        let httpRequest = buildRequest(url: url, apiKey: try apiKey())
        let body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )

        let state = StreamingState(startTime: CFAbsoluteTimeGetCurrent())
        let chunkHandler = onChunk
        try await apiService.sendStreamingRequest(request: httpRequest, body: body) { [self] chunkData in
            await Self.processStreamChunk(
                chunkData: chunkData,
                parse: { try self.adapter.parseStreamChunk(data: $0) },
                state: state,
                onChunk: chunkHandler
            )
        }

        await state.saveCurrentToolCall()
        if let error = await state.streamError {
            throw LumiLLMProviderSupportError.streamingFailed(error)
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: await state.accumulatedContentChunks.joined(),
            providerID: Self.info.id,
            modelName: request.model,
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            }
        )
    }

    private func apiKey() throws -> String {
        if let storedKey = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey),
           !storedKey.isEmpty {
            return storedKey
        }

        if let environmentAPIKeyName = Self.environmentAPIKeyName,
           let environmentKey = ProcessInfo.processInfo.environment[environmentAPIKeyName],
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentKey
        }

        throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
    }

    fileprivate static func processStreamChunk(
        chunkData: Data,
        parse: (Data) throws -> StreamChunk?,
        state: StreamingState,
        onChunk: @Sendable (LumiStreamChunk) async -> Void
    ) async -> Bool {
        do {
            try Task.checkCancellation()
            guard let parsed = try parse(chunkData) else {
                return true
            }

            if let content = parsed.content, parsed.eventType == .textDelta {
                await state.recordFirstToken()
                await state.appendContent(content)
                await onChunk(LumiStreamChunk(content: content, eventTitle: "生成中"))
            }

            if let content = parsed.content, parsed.eventType == .thinkingDelta {
                await state.appendThinking(content)
                await onChunk(LumiStreamChunk(content: content, isThinking: true, eventTitle: "思考中"))
            }

            if let toolCalls = parsed.toolCalls {
                await state.saveCurrentToolCall()
                if let firstToolCall = toolCalls.first {
                    await state.startNewToolCall(
                        id: firstToolCall.id,
                        name: firstToolCall.name,
                        hasPartialJson: parsed.partialJson != nil,
                        arguments: firstToolCall.arguments
                    )
                }
            }

            if let partialJson = parsed.partialJson {
                await state.appendToolCallArguments(partialJson)
            }

            if let error = parsed.error {
                await state.setError(error)
            }

            if parsed.isDone {
                await state.saveCurrentToolCall()
                await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
                return false
            }

            return true
        } catch is CancellationError {
            return false
        } catch {
            return true
        }
    }
}

open class AnthropicCompatibleLumiProvider: LumiLLMProvider, @unchecked Sendable {
    open class var info: LumiLLMProviderInfo {
        fatalError("Subclasses must override info")
    }

    open class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_\(info.id)"
    }

    open class var environmentAPIKeyName: String? {
        nil
    }

    private let apiService: LLMAPIService
    private let adapter: AnthropicCompatibleProviderAdapter

    public init(
        configuration: AnthropicCompatibleProviderConfiguration,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        self.apiService = apiService
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
    }

    open func buildRequest(url: URL, apiKey: String) -> URLRequest {
        adapter.buildRequest(url: url, apiKey: apiKey)
    }

    open func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    open func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw LumiLLMProviderSupportError.emptyConversation
        }

        guard let url = URL(string: adapter.configuration.baseURL) else {
            throw LumiLLMProviderSupportError.invalidBaseURL(adapter.configuration.baseURL)
        }

        let httpRequest = buildRequest(url: url, apiKey: try apiKey())
        let body = try adapter.buildStreamingRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )

        let state = StreamingState(startTime: CFAbsoluteTimeGetCurrent())
        let chunkHandler = onChunk
        try await apiService.sendStreamingRequest(request: httpRequest, body: body) { [self] chunkData in
            await OpenAICompatibleLumiProvider.processStreamChunk(
                chunkData: chunkData,
                parse: { try self.adapter.parseStreamChunk(data: $0) },
                state: state,
                onChunk: chunkHandler
            )
        }

        await state.saveCurrentToolCall()
        if let error = await state.streamError {
            throw LumiLLMProviderSupportError.streamingFailed(error)
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: await state.accumulatedContentChunks.joined(),
            providerID: Self.info.id,
            modelName: request.model,
            toolCalls: await state.getFinalToolCalls()?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            }
        )
    }

    private func apiKey() throws -> String {
        if let storedKey = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey),
           !storedKey.isEmpty {
            return storedKey
        }

        if let environmentAPIKeyName = Self.environmentAPIKeyName,
           let environmentKey = ProcessInfo.processInfo.environment[environmentAPIKeyName],
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentKey
        }

        throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
    }
}

public enum LumiLLMProviderSupportError: LocalizedError {
    case emptyConversation
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case streamingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyConversation:
            "LLM request has no conversation."
        case .invalidBaseURL(let url):
            "Invalid provider base URL: \(url)"
        case .missingAPIKey(let providerName):
            "\(providerName) API Key is not configured."
        case .streamingFailed(let message):
            message
        }
    }
}

private struct LumiToolSchema: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
