import Foundation

enum StepFunTransportError: LocalizedError {
    case networkUnavailable
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "StepFun network service is unavailable"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}