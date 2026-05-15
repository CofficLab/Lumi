import Foundation

public enum OpenAICompatibleProviderError: Error, Equatable, LocalizedError {
    case noChoices
    case apiError(message: String)

    public var errorDescription: String? {
        switch self {
        case .noChoices:
            "No choices in response"
        case let .apiError(message):
            message
        }
    }
}
