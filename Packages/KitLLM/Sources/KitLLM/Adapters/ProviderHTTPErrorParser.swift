import Foundation

/// 从 HTTP 响应体解析供应商错误。
public struct ProviderHTTPError: Sendable, Equatable {
    public let message: String
    public let statusCode: Int?
    public let isRetryable: Bool

    public init(message: String, statusCode: Int?, isRetryable: Bool) {
        self.message = message
        self.statusCode = statusCode
        self.isRetryable = isRetryable
    }
}

public enum ProviderHTTPErrorParser {
    public static func parseOpenAICompatible(data: Data?, statusCode: Int?) -> ProviderHTTPError? {
        guard let data else { return nil }
        if let decoded = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data) {
            return ProviderHTTPError(
                message: decoded.error.message,
                statusCode: statusCode,
                isRetryable: isRetryableStatusCode(statusCode)
            )
        }
        return parseGenericJSON(data: data, statusCode: statusCode)
    }

    public static func parseAnthropicCompatible(data: Data?, statusCode: Int?) -> ProviderHTTPError? {
        guard let data else { return nil }
        if let decoded = try? JSONDecoder().decode(AnthropicCompatibleErrorResponse.self, from: data) {
            return ProviderHTTPError(
                message: decoded.error.message,
                statusCode: statusCode,
                isRetryable: isRetryableStatusCode(statusCode)
            )
        }
        return parseGenericJSON(data: data, statusCode: statusCode)
    }

    public static func parseGenericJSON(data: Data?, statusCode: Int?) -> ProviderHTTPError? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return ProviderHTTPError(
                message: message,
                statusCode: statusCode,
                isRetryable: isRetryableStatusCode(statusCode)
            )
        }

        if let message = json["message"] as? String {
            return ProviderHTTPError(
                message: message,
                statusCode: statusCode,
                isRetryable: isRetryableStatusCode(statusCode)
            )
        }

        return nil
    }

    private static func isRetryableStatusCode(_ statusCode: Int?) -> Bool {
        guard let statusCode else { return false }
        return statusCode == 429 || (500 ... 599).contains(statusCode)
    }
}
