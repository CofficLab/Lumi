import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class ZhipuProvider: AnthropicCompatibleLumiProvider, @unchecked Sendable {
    public static let shortName = "ZhiPu"
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "zhipu",
            displayName: LumiPluginLocalization.string("智谱", bundle: .module),
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
            websiteURL: URL(string: "https://open.bigmodel.cn/")
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Zhipu"
    }

    public override class var environmentAPIKeyName: String? {
        "ZHIPU_API_KEY"
    }

    // Claude Code 模拟常量
    private static let claudeCodeVersion = "2.0.53-dev.20251124.t173302"
    private static let claudeCodeUserType = "cli"
    private static let sessionID = UUID().uuidString

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://open.bigmodel.cn/api/anthropic/v1/messages"
            )
        )
    }

    // MARK: - Request Building

    public override func buildRequest(url: URL, apiKey: String) -> URLRequest {
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

    // MARK: - Send (with error rendering)

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

    // MARK: - API Key

    public static func getApiKey() -> String {
        LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        LumiAPIKeyStore.shared.set(apiKey, forKey: apiKeyStorageKey)
    }

    // MARK: - Error Handling

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
            return ZhipuRenderKind.apiKeyMissing
        }

        if case let HTTPClientError.httpError(statusCode, _) = error {
            return ZhipuRenderKind.http(statusCode)
        }

        if case let LumiLLMProviderSupportError.streamingFailed(message) = error,
           let statusCode = parseHTTPStatusCode(from: message) {
            return ZhipuRenderKind.http(statusCode)
        }

        return ZhipuRenderKind.requestFailed
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

    // MARK: - Claude Code 模拟辅助方法

    /// 生成 Claude Code 风格的 User-Agent
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
