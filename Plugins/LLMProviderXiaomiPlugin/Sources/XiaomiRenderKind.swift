import LumiCoreMessage
import LumiKernel

/// 小米供应商错误消息的渲染类型判定。
///
/// 小米 TokenPlan（`xiaomi`）与小米 API（`xiaomi-api`）共用同一套错误渲染界面，
/// 因此 `isXiaomiError` 同时匹配这两个 provider id。错误消息的 `renderKind` 由
/// `errorRenderKind(for:)` 设置，供 `XiaomiPlugin.messageRenderers` 选择渲染器。
enum XiaomiRenderKind {
    static let apiKeyMissing = "xiaomi-api-key-missing"
    static let requestFailed = "xiaomi-request-failed"

    /// 小米相关的 provider id（TokenPlan + 小米 API）。
    static let providerIDs: Set<String> = ["xiaomi", "xiaomi-api"]

    static func http(_ statusCode: Int) -> String {
        "xiaomi-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("xiaomi-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("xiaomi-http-".count))
    }

    static func isXiaomiError(_ message: LumiChatMessage) -> Bool {
        guard let providerID = message.providerID else { return false }
        return message.isError && providerIDs.contains(providerID)
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isXiaomiError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isXiaomiError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isXiaomiError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}
