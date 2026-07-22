import LumiKernel
import LumiKernel

enum StepFunRenderKind {
    static let apiKeyMissing = "stepfun-api-key-missing"
    static let requestFailed = "stepfun-request-failed"

    static func http(_ statusCode: Int) -> String {
        "stepfun-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("stepfun-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("stepfun-http-".count))
    }

    static func isStepFunError(_ message: LumiChatMessage) -> Bool {
        message.isError && message.providerID == StepFunProvider.info.id
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isStepFunError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isStepFunError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isStepFunError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}
