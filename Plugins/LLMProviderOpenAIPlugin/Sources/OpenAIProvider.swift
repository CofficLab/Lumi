import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
import LumiCoreKit

public final class OpenAIProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "openai",
        displayName: LumiPluginLocalization.string("OpenAI", bundle: .module),
        description: LumiPluginLocalization.string("GPT by OpenAI", bundle: .module),
        defaultModel: "gpt-4o",
        availableModels: [
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-4-turbo",
            "gpt-4",
            "gpt-3.5-turbo"
        ]
    )

    private static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenAI"

    private let apiService: LLMAPIService
    private let adapter: OpenAICompatibleProviderAdapter

    public init(
        apiService: LLMAPIService = LLMAPIService(),
        adapter: OpenAICompatibleProviderAdapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://api.openai.com/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: true,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    ) {
        self.apiService = apiService
        self.adapter = adapter
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw OpenAIProviderError.emptyConversation
        }

        let apiKey = try apiKey()
        guard let url = URL(string: adapter.configuration.baseURL) else {
            throw OpenAIProviderError.invalidBaseURL(adapter.configuration.baseURL)
        }

        let httpRequest = adapter.buildRequest(url: url, apiKey: apiKey)
        let body = try adapter.buildRequestBody(
            messages: request.messages.map(Self.convertMessage),
            model: request.model,
            tools: request.tools.map(OpenAIToolSchema.init),
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(request: httpRequest, body: body)
        let response = try adapter.parseResponse(data: data)

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: response.content,
            providerID: Self.info.id,
            modelName: request.model,
            toolCalls: response.toolCalls?.map {
                LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            }
        )
    }

    private static func convertMessage(_ message: LumiChatMessage) -> LLMProviderKit.ChatMessage {
        LLMProviderKit.ChatMessage(
            role: convertRole(message.role),
            content: message.content,
            toolCalls: message.toolCalls?.map {
                LLMProviderKit.ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments)
            },
            toolCallID: message.toolCallID
        )
    }

    private static func convertRole(_ role: LumiChatMessageRole) -> LLMProviderKit.MessageRole {
        switch role {
        case .system:
            .system
        case .user:
            .user
        case .assistant:
            .assistant
        case .tool:
            .tool
        case .error, .status:
            .error
        }
    }

    private func apiKey() throws -> String {
        if let storedKey = UserDefaults.standard.string(forKey: Self.apiKeyStorageKey),
           !storedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storedKey
        }

        if let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !environmentKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentKey
        }

        throw OpenAIProviderError.missingAPIKey
    }
}

private struct OpenAIToolSchema: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}

enum OpenAIProviderError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL(String)
    case emptyConversation

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API Key is not configured."
        case let .invalidBaseURL(url):
            "Invalid OpenAI base URL: \(url)"
        case .emptyConversation:
            "OpenAI request has no conversation."
        }
    }
}
