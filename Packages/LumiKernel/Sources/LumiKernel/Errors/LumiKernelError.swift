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
        }
    }
}
