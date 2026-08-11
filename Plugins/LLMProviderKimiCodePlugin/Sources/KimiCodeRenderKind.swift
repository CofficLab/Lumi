import LumiKernel

enum KimiCodeRenderKind {
    static let apiKeyMissing = "kimi-code-api-key-missing"
    static let requestFailed = "kimi-code-request-failed"

    static func http(_ statusCode: Int) -> String {
        "kimi-code-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("kimi-code-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("kimi-code-http-".count))
    }

    static func isKimiCodeError(_ message: LumiChatMessage) -> Bool {
        guard let providerID = message.providerID else { return false }
        return message.isError && (providerID == KimiCodeOpenAIProvider.info.id || providerID == KimiCodeAnthropicProvider.info.id)
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isKimiCodeError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isKimiCodeError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isKimiCodeError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}