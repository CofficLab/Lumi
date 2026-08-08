import Foundation

enum AliyunTransportError: LocalizedError {
    case networkUnavailable
    case invalidURL(String)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "Aliyun network service is unavailable"
        case let .invalidURL(url): "Invalid Aliyun URL: \(url)"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}
