import Foundation

enum MiniMaxMusicError: LocalizedError, Equatable {
    case missingAPIKey
    case apiError(code: Int, message: String)
    case noAudioReturned
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .noAudioReturned:
            return "MiniMax did not return any audio. The prompt or lyrics may have been blocked by content safety."
        case .cancelled:
            return "MiniMax music generation was cancelled."
        }
    }
}
