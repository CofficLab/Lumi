import Foundation
import HttpKit
import LLMKit
import LumiLLMProviderSupport
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import SuperLogKit
import os

// MARK: - SublyxToolNameMapper

/// Sublyx 工具名称映射器
private enum SublyxToolNameMapper {
    static func toAPIName(_ name: String) -> String {
        name.replacingOccurrences(of: ".", with: "_")
    }
    
    static func buildReverseMapping(from tools: [any LumiAgentTool]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: tools.map {
            (toAPIName($0.name), $0.name)
        })
    }
    
    static func fromAPIName(_ apiName: String, reverseMapping: [String: String]) -> String {
        reverseMapping[apiName] ?? apiName
    }
}

// MARK: - SublyxMappedTool

private struct SublyxMappedTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "sublyx-mapped",
        displayName: "Mapped Tool",
        description: "Internal wrapper for Sublyx API name mapping"
    )
    
    private let wrapped: any LumiAgentTool
    private let mappedName: String
    
    init(wrapped: any LumiAgentTool, apiName: String) {
        self.wrapped = wrapped
        self.mappedName = apiName
    }
    
    var name: String { mappedName }
    var toolDescription: String { wrapped.toolDescription }
    var inputSchema: LumiJSONValue { wrapped.inputSchema }
    
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await wrapped.execute(arguments: arguments, context: context)
    }
    
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        wrapped.riskLevel(arguments: arguments, context: context)
    }
    
    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        wrapped.displayDescription(arguments: arguments)
    }
}

// MARK: - SublyxProvider

public final class SublyxProvider: LumiLLMProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "📡"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.sublyx")
    
    public static let apiKeyHelpURL: String? = "https://api.sublyx.org/"
    
    public static let info = LumiLLMProviderInfo(
        id: "sublyx",
        displayName: LumiPluginLocalization.string("Sublyx", bundle: .module),
        description: LumiPluginLocalization.string("GPT API Gateway by Sublyx", bundle: .module),
        defaultModel: "gpt-5.5",
        availableModels: [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-4o",
            "gpt-4.1"
        ],
        contextWindowSizes: [
            "gpt-5.5": 1_000_000,
            "gpt-5.4": 1_000_000,
            "gpt-5.4-mini": 1_000_000,
            "gpt-4o": 128_000,
            "gpt-4.1": 1_000_000
        ],
        modelCapabilities: [
            "gpt-5.5": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
            "gpt-4o": .init(supportsVision: true, supportsTools: true),
            "gpt-4.1": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://api.sublyx.org/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Sublyx"
    )
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.sublyx.org/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        self.adapter = OpenAICompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
    // MARK: - Internal Access for AvailabilityService
    
    var internalAdapter: OpenAICompatibleProviderAdapter { adapter }
    var internalApiService: LLMAPIService { apiService }
    
    // MARK: - LumiLLMProvider Protocol
    
    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(
            storageKey: Self.info._apiKeyStorageKey,
            displayName: Self.info.displayName
        )
    }
    
    public func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }
    
    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        // 构建反向映射表并包装工具
        let reverseMapping = SublyxToolNameMapper.buildReverseMapping(from: request.tools)
        
        let mappedTools: [any LumiAgentTool] = request.tools.map { tool in
            SublyxMappedTool(wrapped: tool, apiName: SublyxToolNameMapper.toAPIName(tool.name))
        }
        
        let adaptedRequest = LumiLLMRequest(
            messages: request.messages,
            model: request.model,
            tools: mappedTools,
            imageAttachments: request.imageAttachments
        )
        
        // 日志：输出原始和适配后的工具名称
        if !request.tools.isEmpty {
            let originalNames = request.tools.map(\.name)
            let adaptedNames = mappedTools.map(\.name)
            Self.logger.info("\(Self.t)原始工具名称: \(originalNames)")
            Self.logger.info("\(Self.t)适配后工具名称: \(adaptedNames)")
        }
        
        do {
            let message = try await LumiStreamingRequestSupport.sendOpenAICompatibleStreaming(
                adaptedRequest,
                adapter: adapter,
                apiService: apiService,
                baseURLs: [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs,
                resolveAPIKey: lumiResolveAPIKey,
                buildRequest: { url, apiKey in
                    adapter.buildRequest(url: url, apiKey: apiKey)
                },
                onChunk: onChunk
            )
            return Self.restoreToolCallNames(in: message, reverseMapping: reverseMapping)
        } catch {
            if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error),
               !(200..<300).contains(statusCode)
            {
                Self.logger.error("\(Self.t)HTTP \(statusCode) 错误响应: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return SublyxRenderKind.apiKeyMissing
        }
        
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return SublyxRenderKind.http(statusCode)
        }
        
        return SublyxRenderKind.requestFailed
    }
    
    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: Self.info.id,
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: errorRenderKind(for: error)
        )
    }
    
    // MARK: - Tool Name Restoration
    
    private static func restoreToolCallNames(
        in message: LumiChatMessage,
        reverseMapping: [String: String]
    ) -> LumiChatMessage {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
            return message
        }
        
        let restoredToolCalls = toolCalls.map { toolCall -> LumiToolCall in
            let originalName = SublyxToolNameMapper.fromAPIName(toolCall.name, reverseMapping: reverseMapping)
            if originalName != toolCall.name {
                Self.logger.info("\(Self.t)还原工具调用名称: '\(toolCall.name)' -> '\(originalName)'")
            }
            return LumiToolCall(
                id: toolCall.id,
                name: originalName,
                arguments: toolCall.arguments,
                result: toolCall.result,
                displayName: toolCall.displayName
            )
        }
        
        var restored = message
        restored.toolCalls = restoredToolCalls
        return restored
    }
}