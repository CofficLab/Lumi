import Foundation

/// Projects 插件注册错误
public enum ProjectsPluginError: LocalizedError {
    case toolManagerNotAvailable
    case sendMiddlewareNotAvailable

    public var errorDescription: String? {
        switch self {
        case .toolManagerNotAvailable:
            "ToolManager service not available, cannot register agent tools"
        case .sendMiddlewareNotAvailable:
            "SendMiddleware service not available, cannot register middleware"
        }
    }
}
