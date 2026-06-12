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
            ]
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
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: info.id,
            isError: true,
            rawErrorDetail: error.localizedDescription,
            renderKind: renderKind(for: error)
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
