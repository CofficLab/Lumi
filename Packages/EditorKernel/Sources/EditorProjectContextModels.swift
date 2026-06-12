import Foundation

public struct EditorProjectContextSnapshot: Equatable, Sendable {
    public let projectPath: String
    public let workspaceName: String
    public let workspacePath: String
    public let activeScheme: String?
    public let activeSchemeBuildableTargets: [String]
    public let activeConfiguration: String?
    public let activeDestination: String?
    public let contextStatus: EditorProjectContextStatus
    public let isStructuredProject: Bool
    public let schemes: [String]
    public let configurations: [String]
    public let currentFilePath: String?
    public let currentFilePrimaryTarget: String?
    public let currentFileMatchedTargets: [String]
    public let currentFileIsInTarget: Bool

    public init(
        projectPath: String,
        workspaceName: String,
        workspacePath: String,
        activeScheme: String?,
        activeSchemeBuildableTargets: [String],
        activeConfiguration: String?,
        activeDestination: String?,
        contextStatus: EditorProjectContextStatus,
        isStructuredProject: Bool,
        schemes: [String],
        configurations: [String],
        currentFilePath: String?,
        currentFilePrimaryTarget: String?,
        currentFileMatchedTargets: [String],
        currentFileIsInTarget: Bool
    ) {
        self.projectPath = projectPath
        self.workspaceName = workspaceName
        self.workspacePath = workspacePath
        self.activeScheme = activeScheme
        self.activeSchemeBuildableTargets = activeSchemeBuildableTargets
        self.activeConfiguration = activeConfiguration
        self.activeDestination = activeDestination
        self.contextStatus = contextStatus
        self.isStructuredProject = isStructuredProject
        self.schemes = schemes
        self.configurations = configurations
        self.currentFilePath = currentFilePath
        self.currentFilePrimaryTarget = currentFilePrimaryTarget
        self.currentFileMatchedTargets = currentFileMatchedTargets
        self.currentFileIsInTarget = currentFileIsInTarget
    }
}

public enum EditorProjectContextStatus: Equatable, Sendable {
    case unknown
    case resolving
    case available(String?)
    case unavailable(String)
    case needsResync

    public var displayDescription: String {
        switch self {
        case .unknown:
            return "未初始化"
        case .resolving:
            return "解析中"
        case .available(let detail):
            return detail ?? "可用"
        case .unavailable(let reason):
            return "不可用: \(reason)"
        case .needsResync:
            return "需要重新同步"
        }
    }
}
