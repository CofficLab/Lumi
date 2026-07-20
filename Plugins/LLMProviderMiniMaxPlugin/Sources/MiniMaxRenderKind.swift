import LumiCoreMessage
import LumiKernel

/// MiniMax Token Plan 错误消息的渲染类型判定。
///
/// 错误消息的 `renderKind` 由 `MiniMaxTokenPlanProvider.errorRenderKind(for:)`
/// 设置，供 `MiniMaxPlugin.messageRenderers` 选择对应渲染器。所有 renderKind
/// 使用 `minimax-` 前缀，避免与其他供应商冲突。
enum MiniMaxRenderKind {
    static let prefix = "minimax-"
    static let apiKeyMissing = "minimax-api-key-missing"
    static let requestFailed = "minimax-request-failed"

    static func http(_ statusCode: Int) -> String {
        "minimax-http-\(statusCode)"
    }

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("minimax-http-") else {
            return nil
        }
        return Int(renderKind.dropFirst("minimax-http-".count))
    }

    static func isMiniMaxError(_ message: LumiChatMessage) -> Bool {
        message.isError && message.providerID == MiniMaxTokenPlanProvider.info.id
    }

    static func matches(renderKind expected: String, message: LumiChatMessage) -> Bool {
        isMiniMaxError(message) && message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: LumiChatMessage) -> Bool {
        isMiniMaxError(message) && httpStatusCode(from: message.renderKind) == statusCode
    }

    static func matchesApiKeyMissing(_ message: LumiChatMessage) -> Bool {
        matches(renderKind: apiKeyMissing, message: message)
    }

    static func matchesOtherHttpError(_ message: LumiChatMessage) -> Bool {
        guard isMiniMaxError(message),
              let code = httpStatusCode(from: message.renderKind)
        else {
            return false
        }
        return code != 401 && code != 403
    }
}