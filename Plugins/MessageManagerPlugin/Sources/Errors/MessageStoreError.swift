import Foundation

public enum MessageStoreError: Error, LocalizedError {
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .initializationFailed(message):
            return message
        }
    }
}
