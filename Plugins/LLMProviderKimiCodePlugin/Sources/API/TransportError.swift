import Foundation

enum KimiCodeTransportError: LocalizedError {
    case networkUnavailable
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "Kimi Code network service is unavailable"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}

enum KimiCodeAnthropicTransportError: LocalizedError {
    case networkUnavailable
    case invalidURL(String)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "Network is unavailable"
        case let .invalidURL(url): "Invalid Kimi Code Anthropic URL: \(url)"
        case let .httpStatus(code, body): "Kimi Code Anthropic HTTP \(code): \(body)"
        }
    }
}
