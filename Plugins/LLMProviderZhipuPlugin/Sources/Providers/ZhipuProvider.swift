import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LLMKit
import LumiCoreKit

public final class ZhipuProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "ZhiPu"
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"
    
    public static let info = LumiLLMProviderInfo(
        id: "zhipu",
        displayName: LumiPluginLocalization.string("智谱 Coding Plan", bundle: .module),
        description: LumiPluginLocalization.string("Zhipu AI GLM", bundle: .module),
        defaultModel: "glm-4.7",
        availableModels: [
            "glm-5.2",
            "glm-5.1",
            "glm-5-turbo",
            "glm-5",
            "glm-4.7",
            "glm-4.6",
            "glm-4.5",
            "glm-4.5-air",
        ],
        contextWindowSizes: [
            "glm-5.2": 1_000_000,
            "glm-5.1": 1_000_000,
            "glm-5-turbo": 1_000_000,
            "glm-5": 1_000_000,
            "glm-4.7": 128_000,
            "glm-4.6": 200_000,
            "glm-4.5": 128_000,
            "glm-4.5-air": 128_000
        ],
        modelCapabilities: [
            "glm-5.2": .init(supportsVision: true, supportsTools: true),
            "glm-5.1": .init(supportsVision: true, supportsTools: true),
            "glm-5-turbo": .init(supportsVision: true, supportsTools: true),
            "glm-5": .init(supportsVision: true, supportsTools: true),
            "glm-4.7": .init(supportsVision: false, supportsTools: true),
            "glm-4.6": .init(supportsVision: true, supportsTools: true),
            "glm-4.5": .init(supportsVision: true, supportsTools: true),
            "glm-4.5-air": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://www.bigmodel.cn/")!,
        apiKeyStorageKey: "DevAssistant_ApiKey_Zhipu"
    )
    
    private let adapter: AnthropicCompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    // Claude Code 模拟常量
    private static let claudeCodeVersion = "2.0.53-dev.20251124.t173302"
    private static let claudeCodeUserType = "cli"
    private static let sessionID = UUID().uuidString
    
    public init(
        configuration: AnthropicCompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? AnthropicCompatibleProviderConfiguration(
            baseURL: "https://open.bigmodel.cn/api/anthropic/v1/messages"
        )
        self.adapter = AnthropicCompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
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
        try await LumiStreamingRequestSupport.sendAnthropicCompatibleStreaming(
            request,
            adapter: adapter,
            apiService: apiService,
            baseURLs: [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs,
            resolveAPIKey: lumiResolveAPIKey,
            buildRequest: { url, apiKey in
                buildRequest(url: url, apiKey: apiKey)
            },
            onChunk: onChunk
        )
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(model: model, check: { model in
            await LumiAnthropicCompatibleAvailability.chatPing(
                model: model,
                adapter: self.adapter,
                apiService: self.apiService,
                buildRequest: { url, apiKey in
                    self.buildRequest(url: url, apiKey: apiKey)
                },
                resolveAPIKey: self.lumiResolveAPIKey
            )
        })
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return ZhipuRenderKind.apiKeyMissing
        }
        
        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return ZhipuRenderKind.http(statusCode)
        }
        
        return ZhipuRenderKind.requestFailed
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
    
    // MARK: - Request Building
    
    private func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 认证：支持 Bearer token 和 x-api-key 两种方式
        if apiKey.hasPrefix("Bearer ") || apiKey.contains("Bearer") {
            let cleanToken = apiKey
                .replacingOccurrences(of: "Bearer ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        // Anthropic 兼容头部
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Claude Code 特有头部
        request.addValue("cli", forHTTPHeaderField: "x-app")
        request.addValue(Self.getClaudeCodeUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue(Self.sessionID, forHTTPHeaderField: "X-Claude-Code-Session-Id")
        
        if let clientApp = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            request.addValue(clientApp, forHTTPHeaderField: "x-client-app")
        }
        
        return request
    }
    
    // MARK: - Claude Code 模拟辅助方法
    
    private static func getClaudeCodeUserAgent() -> String {
        let version = claudeCodeVersion
        let userType = claudeCodeUserType
        let entrypoint = "cli"
        
        var userAgent = "claude-cli/\(version) (\(userType), \(entrypoint)"
        
        if let sdkVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            userAgent += ", sdk/\(sdkVersion)"
        }
        
        if let clientApp = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                userAgent += ", client-app/\(clientApp)/\(appVersion)"
            }
        }
        
        userAgent += ")"
        
        return userAgent
    }
}