import Foundation

enum MiniMaxVideoError: LocalizedError, Equatable {
    case missingAPIKey
    case apiError(code: Int, message: String)
    case taskFailed(message: String)
    case missingDownloadURL
    case downloadFailed(message: String)
    case pollingTimeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "MiniMax API Key is not configured. Please add your API key in Lumi settings."
        case .apiError(let code, let message):
            return "MiniMax API error (code=\(code)): \(message)"
        case .taskFailed(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "MiniMax video generation failed." : "MiniMax video generation failed: \(trimmed)"
        case .missingDownloadURL:
            return "MiniMax did not return a download URL for the generated video."
        case .downloadFailed(let message):
            return "Failed to download the generated video: \(message)"
        case .pollingTimeout:
            return "MiniMax video generation took too long and was aborted after the polling timeout."
        case .cancelled:
            return "MiniMax video generation was cancelled."
        }
    }
}
