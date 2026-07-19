import LumiKernel

enum ZhipuRenderKind {
    static let apiKeyMissing = "zhipu-api-key-missing"
    static let requestFailed = "zhipu-request-failed"

    static func http(_ statusCode: Int) -> String {
        "zhipu-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("zhipu-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("zhipu-http-".count))
    }

    static func isZhipuError(_ message: LumiChatMessage) -> Bool {
        message.isError && message.providerID == ZhipuProvider.info.id
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isZhipuError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isZhipuError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isZhipuError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}
