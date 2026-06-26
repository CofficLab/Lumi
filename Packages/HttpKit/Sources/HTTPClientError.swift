import Foundation

public enum HTTPClientError: LocalizedError {
    case jsonSerializationFailed(underlying: Error)
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)
}
