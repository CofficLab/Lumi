import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport
import SuperLogKit
import os

// MARK: - SublyxToolNameMapper

/// Sublyx 工具名称映射器
///
/// Sublyx API 对工具名称有额外限制：仅允许 `^[a-zA-Z0-9_-]+$`，不允许 `.` 字符。
/// 本映射器负责将 `.` 替换为 `_`，并在响应时通过映射表还原。
private enum SublyxToolNameMapper {
    /// 将原始工具名称转换为 Sublyx API 兼容的名称
    static func toAPIName(_ name: String) -> String {
        name.replacingOccurrences(of: ".", with: "_")
    }

    /// 构建反向映射表（API 名称 -> 原始名称）
    static func buildReverseMapping(from tools: [any LumiAgentTool]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: tools.map {
            (toAPIName($0.name), $0.name)
        })
    }

    /// 将 Sublyx API 返回的工具名称还原为原始名称
    static func fromAPIName(_ apiName: String, reverseMapping: [String: String]) -> String {
        reverseMapping[apiName] ?? apiName
    }
}

// MARK: - SublyxMappedTool

/// 工具名称映射包装器
///
/// 将 `LumiAgentTool` 包装后仅替换 `name` 属性，其余全部代理给原始工具。
/// 用于在发送给 Sublyx API 前将工具名称中的 `.` 替换为 `_`。
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

public final class SublyxProvider: OpenAICompatibleLumiProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "📡"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.sublyx")

    public static let apiKeyHelpURL: String? = "https://api.sublyx.org/"

    private static let apiKeyStorageKey = "DevAssistant_ApiKey_Sublyx"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
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
            websiteURL: URL(string: "https://api.sublyx.org/")!
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.sublyx.org/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: true,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    override public func lumiResolveAPIKey() throws -> String {
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return SublyxRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return SublyxRenderKind.http(statusCode)
        }

        return SublyxRenderKind.requestFailed
    }

    // MARK: - API Key

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }

    // MARK: - Streaming

    public override func sendStreaming(
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
            let message = try await super.sendStreaming(adaptedRequest, onChunk: onChunk)
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

    // MARK: - Tool Name Restoration

    /// 还原响应消息中工具调用的名称
    ///
    /// Sublyx API 返回的 `toolCall.name` 使用的是映射后的名称（`_` 替换了 `.`），
    /// 需要通过反向映射表还原为原始名称，以便 `ToolService.tool(named:)` 能正确查找工具。
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
