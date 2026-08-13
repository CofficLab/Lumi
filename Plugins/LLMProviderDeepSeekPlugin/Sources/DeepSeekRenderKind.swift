import KernelLumi

enum DeepSeekRenderKind {
    static let apiKeyMissing = "deepseek-api-key-missing"
    static let requestFailed = "deepseek-request-failed"

    static func http(_ statusCode: Int) -> String {
        "deepseek-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("deepseek-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("deepseek-http-".count))
    }

    static func isDeepSeekError(_ message: LumiChatMessage) -> Bool {
        guard let providerID = message.providerID else { return false }
        return message.isError && (providerID == DeepSeekOpenAIProvider.info.id || providerID == DeepSeekAnthropicProvider.info.id)
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isDeepSeekError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isDeepSeekError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isDeepSeekError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}
