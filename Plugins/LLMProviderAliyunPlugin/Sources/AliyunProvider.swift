import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class AliyunProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    public static let shortName = "Aliyun"
    public static let apiKeyHelpURL: String? = "https://help.aliyun.com/zh/model-studio/get-api-key"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "aliyun",
            displayName: LumiPluginLocalization.string("阿里云 CodingPlan", bundle: .module),
            description: LumiPluginLocalization.string("阿里云 DashScope Coding Plan", bundle: .module),
            defaultModel: "qwen3.6-plus",
            availableModels: [
                "qwen3.5-plus",
                "qwen3.6-flash",
                "qwen3.6-plus",
                "qwen3.7-plus",
                "qwen3.7-max",
                "glm-4.7",
                "glm-5",
                "MiniMax-M2.5",
                "kimi-k2.5",
            ],
            contextWindowSizes: [
                "qwen3.5-plus": 131_072,
                "qwen3.6-flash": 1_000_000,
                "qwen3.6-plus": 131_072,
                "qwen3.7-plus": 131_072,
                "qwen3.7-max": 131_072,
                "glm-4.7": 128_000,
                "glm-5": 128_000,
                "MiniMax-M2.5": 1_000_000,
                "kimi-k2.5": 256_000
            ],
            modelCapabilities: [
                "qwen3.5-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.6-flash": .init(supportsVision: true, supportsTools: true),
                "qwen3.6-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.7-plus": .init(supportsVision: true, supportsTools: true),
                "qwen3.7-max": .init(supportsVision: true, supportsTools: true),
                "glm-4.7": .init(supportsVision: false, supportsTools: true),
                "glm-5": .init(supportsVision: true, supportsTools: true),
                "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true),
                "kimi-k2.5": .init(supportsVision: false, supportsTools: true)
            ],
            websiteURL: URL(string: "https://dashscope.console.aliyun.com/")
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Aliyun"
    }

    public override class var environmentAPIKeyName: String? {
        "DASHSCOPE_API_KEY"
    }

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
            )
        )
    }

    public override func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let conversationID = request.messages.first?.conversationID ?? UUID()
        do {
            return try await super.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return Self.errorMessage(conversationID: conversationID, error: error)
        }
    }

    public override func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let conversationID = request.messages.first?.conversationID ?? UUID()
        do {
            return try await super.sendStreaming(request, onChunk: onChunk)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return Self.errorMessage(conversationID: conversationID, error: error)
        }
    }

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }

    static func errorMessage(conversationID: UUID, error: Error) -> LumiChatMessage {
        let fullDetail = LumiLLMProviderSupportLocalization.userFacingDescription(for: error)
        let split = splitTransportDetails(fullDetail)
        var metadata: [String: String] = [:]
        if let request = split.requestDetails, !request.isEmpty {
            metadata["llm.transport.request"] = request
        }
        if let response = split.responseDetails, !response.isEmpty {
            metadata["llm.transport.response"] = response
        }
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: info.id,
            isError: true,
            rawErrorDetail: split.summary,
            renderKind: renderKind(for: error),
            metadata: metadata
        )
    }

    private static func splitTransportDetails(_ fullDetail: String) -> (summary: String, requestDetails: String?, responseDetails: String?) {
        let separator = "\n\n--- Request / Response Details ---\n"
        guard let separatorRange = fullDetail.range(of: separator) else {
            return (summary: fullDetail, requestDetails: nil, responseDetails: nil)
        }

        let summary = String(fullDetail[..<separatorRange.lowerBound])
        let detailsBlock = String(fullDetail[separatorRange.upperBound...])
        guard let responseRange = detailsBlock.range(of: "Response Status:") else {
            let request = detailsBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                summary: summary,
                requestDetails: request.isEmpty ? nil : request,
                responseDetails: nil
            )
        }

        let request = String(detailsBlock[..<responseRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let response = String(detailsBlock[responseRange.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            summary: summary,
            requestDetails: request.isEmpty ? nil : request,
            responseDetails: response.isEmpty ? nil : response
        )
    }

    private static func renderKind(for error: Error) -> String {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return AliyunRenderKind.apiKeyMissing
        }

        if case let HTTPClientError.httpError(statusCode, _) = error {
            return AliyunRenderKind.http(statusCode)
        }

        if case let LumiLLMProviderSupportError.streamingFailed(message) = error,
           let statusCode = parseHTTPStatusCode(from: message) {
            return AliyunRenderKind.http(statusCode)
        }

        return AliyunRenderKind.requestFailed
    }

    private static func parseHTTPStatusCode(from text: String) -> Int? {
        let patterns = [
            #"HTTP 错误 \((\d+)\)"#,
            #"HTTP 错误（(\d+)）"#,
            #"HTTP error \((\d+)\)"#,
            #"HTTP (\d+)"#,
            #"\b(\d{3})\b"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let code = Int(text[range]),
                  (100 ... 599).contains(code)
            else {
                continue
            }
            return code
        }

        return nil
    }
}
