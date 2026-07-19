import LumiKernel

enum SublyxRenderKind {
    static let apiKeyMissing = "sublyx-api-key-missing"
    static let requestFailed = "sublyx-request-failed"

    static func http(_ statusCode: Int) -> String {
        "sublyx-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("sublyx-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("sublyx-http-".count))
    }

    static func isSublyxError(_ message: LumiChatMessage) -> Bool {
        message.isError && message.providerID == SublyxProvider.info.id
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isSublyxError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isSublyxError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }
}
