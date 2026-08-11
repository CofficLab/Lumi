import Foundation

// MARK: - MiniMax Image API Errors

enum MiniMaxImageError: LocalizedError, Equatable {
    case missingAPIKey
    case apiError(code: Int, message: String)
    case noImagesReturned
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .noImagesReturned:
            return "MiniMax did not return any images. The prompt may have been blocked by content safety."
        case .cancelled:
            return "MiniMax image generation was cancelled."
        }
    }
}
