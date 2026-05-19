import Foundation

public enum HTTPClientError: LocalizedError {
    case jsonSerializationFailed(underlying: Error)
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case let .jsonSerializationFailed(error):
            return "JSON 序列化失败：\(error.localizedDescription)"
        case let .requestFailed(error):
            return "请求失败：\(error.localizedDescription)"
        case let .decodingFailed(error):
            return "响应解码失败：\(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case let .httpError(code, message):
            return "HTTP 错误 (\(code)): \(message)"
        }
    }
}
