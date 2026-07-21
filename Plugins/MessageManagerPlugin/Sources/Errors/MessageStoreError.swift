// MARK: - Error

public enum MessageStoreError: Error, LocalizedError {
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return message
        }
    }
}