import LLMKit
import LumiCoreMessage
import LumiKernel

enum AliyunRenderKind {
    static let prefix = "aliyun-"
    static let apiKeyMissing = "aliyun-api-key-missing"
    static let requestFailed = "aliyun-request-failed"

    static func http(_ statusCode: Int) -> String {
        "aliyun-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("aliyun-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("aliyun-http-".count))
    }

    static func isAliyunError(_ message: LumiChatMessage) -> Bool {
        message.isError
            && (message.providerID == AliyunProvider.info.id
                || message.providerID == AliyunTokenPlanProvider.info.id)
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isAliyunError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isAliyunError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isAliyunError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}
