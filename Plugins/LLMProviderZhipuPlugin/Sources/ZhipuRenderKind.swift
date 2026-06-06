import Foundation
import LumiCoreKit

/// 智谱自定义消息渲染标识（写入 ChatMessage.renderKind）。
enum ZhipuRenderKind {
    static let prefix = "zhipu-"

    static let apiKeyMissing = "zhipu-api-key-missing"
    static let requestFailed = "zhipu-request-failed"

    static func http(_ statusCode: Int) -> String {
        "zhipu-http-\(statusCode)"
    }

    // MARK: - 新消息路由解析

    static func httpStatusCode(from renderKind: String?) -> Int? {
        guard let renderKind, renderKind.hasPrefix("zhipu-http-") else { return nil }
        return Int(renderKind.dropFirst("zhipu-http-".count))
    }

    static func isApiKeyMissing(_ renderKind: String?) -> Bool {
        renderKind == apiKeyMissing
    }

    // MARK: - 过渡期：旧 content magic string 兼容

    private static let legacyContentPrefix = "__LUMI_ZHIPU_"

    static func isLegacyContent(_ content: String) -> Bool {
        if content == ChatMessage.apiKeyMissingSystemContentKey { return true }
        return content.hasPrefix(legacyContentPrefix)
    }

    static func legacyHttpStatusCode(from content: String) -> Int? {
        let marker = "\(legacyContentPrefix)HTTP_"
        guard content.hasPrefix(marker), content.hasSuffix("__") else { return nil }
        let inner = content.dropFirst(marker.count).dropLast(2)
        return Int(inner)
    }

    static func isLegacyApiKeyMissing(_ content: String) -> Bool {
        content == ChatMessage.apiKeyMissingSystemContentKey
    }

    // MARK: - 渲染器匹配

    static func isZhipuError(_ message: ChatMessage) -> Bool {
        message.isError && message.providerId == ZhipuProvider.id
    }

    static func matches(renderKind expected: String, message: ChatMessage) -> Bool {
        guard isZhipuError(message) else { return false }
        return message.renderKind == expected
    }

    static func matchesHttp(statusCode: Int, message: ChatMessage) -> Bool {
        guard isZhipuError(message) else { return false }
        if httpStatusCode(from: message.renderKind) == statusCode { return true }
        return legacyHttpStatusCode(from: message.content) == statusCode
    }

    static func matchesApiKeyMissing(_ message: ChatMessage) -> Bool {
        guard isZhipuError(message) else { return false }
        if isApiKeyMissing(message.renderKind) { return true }
        return isLegacyApiKeyMissing(message.content)
    }

    static func matchesOtherHttpError(_ message: ChatMessage) -> Bool {
        guard isZhipuError(message) else { return false }
        if let code = httpStatusCode(from: message.renderKind), code != 401, code != 403 {
            return true
        }
        if let code = legacyHttpStatusCode(from: message.content), code != 401, code != 403 {
            return true
        }
        return false
    }
}
