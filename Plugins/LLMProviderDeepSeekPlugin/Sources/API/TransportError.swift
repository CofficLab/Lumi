import Foundation

enum DeepSeekTransportError: LocalizedError {
    case networkUnavailable
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "DeepSeek network service is unavailable"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}
