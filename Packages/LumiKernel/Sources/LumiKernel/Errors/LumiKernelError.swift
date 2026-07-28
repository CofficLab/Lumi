import Foundation

/// LumiKernel 错误
public enum LumiKernelError: Error, LocalizedError {
    case pluginAlreadyRegistered(id: String)
    case pluginNotFound(id: String)
    case missingRequiredServices([String])
    case serviceNotAvailable(service: String)
    case noActiveConversation
    case llmProviderUnavailable
    case invalidProviderOrModel
    case llmProviderRegistrationFailed(providerType: String, reason: String)
    case networkRequestFailed(url: String, reason: String)
    case networkInvalidResponse(url: String)
    case networkTimeout(url: String, timeout: TimeInterval)
    case networkHTTPError(url: String, statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .pluginAlreadyRegistered(let id):
            return "Plugin '\(id)' is already registered"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        case .missingRequiredServices(let services):
            return "Missing required services: \(services.joined(separator: ", "))"
        case .serviceNotAvailable(let service):
            return "\(service) service is not available"
        case .noActiveConversation:
            return "No active conversation — create one or pass an explicit conversationID"
        case .llmProviderUnavailable:
            return "No LLM provider is registered with the kernel"
        case .invalidProviderOrModel:
            return "No valid LLM provider or model selected"
        case .llmProviderRegistrationFailed(let providerType, let reason):
            return "Failed to register LLM provider '\(providerType)': \(reason)"
        case .networkRequestFailed(let url, let reason):
            return "Network request to '\(url)' failed: \(reason)"
        case .networkInvalidResponse(let url):
            return "Invalid response from '\(url)'"
        case .networkTimeout(let url, let timeout):
            return "Request to '\(url)' timed out after \(String(format: "%.1f", timeout))s"
        case .networkHTTPError(let url, let statusCode):
            return "HTTP error \(statusCode) for '\(url)'"
        }
    }
}
