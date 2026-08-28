import Foundation

public enum HTTPClientError: LocalizedError {
    case jsonSerializationFailed(underlying: Error)
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .jsonSerializationFailed(let underlying):
            return "JSON serialization failed: \(underlying.localizedDescription)"
        case .requestFailed(let underlying):
            return "Request failed: \(underlying.localizedDescription)"
        case .decodingFailed(let underlying):
            return "Decoding failed: \(underlying.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from server."
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        }
    }
}
