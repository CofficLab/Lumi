import Foundation

enum XiaomiTransportError: LocalizedError {
    case networkUnavailable
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "Xiaomi network service is unavailable"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}
