import Foundation

/// Projects 插件注册错误
public enum ProjectsPluginError: LocalizedError {
    case toolManagerNotAvailable

    public var errorDescription: String? {
        switch self {
        case .toolManagerNotAvailable:
            "ToolManager service not available, cannot register agent tools"
        }
    }
}
