import Foundation

// MARK: - Errors

/// LumiKernel 错误
public enum LumiKernelError: Error, LocalizedError {
    case pluginAlreadyRegistered(id: String)
    case pluginNotFound(id: String)
    case missingRequiredServices([String])

    public var errorDescription: String? {
        switch self {
        case .pluginAlreadyRegistered(let id):
            return "Plugin '\(id)' is already registered"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        case .missingRequiredServices(let services):
            return "Missing required services: \(services.joined(separator: ", "))"
        }
    }
}
