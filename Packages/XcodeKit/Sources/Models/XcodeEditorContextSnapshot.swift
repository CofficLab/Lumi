import Foundation

/// 供编辑器主链路消费的 Xcode 工程上下文快照
public struct XcodeEditorContextSnapshot: Sendable, Equatable {
    public let projectPath: String
    public let workspaceName: String
    public let workspacePath: String
    public let activeScheme: String?
    public let activeSchemeBuildableTargets: [String]
    public let activeConfiguration: String?
    public let activeDestination: String?
    public let buildContextStatus: String
    public let isXcodeProject: Bool
    public let schemes: [String]
    public let configurations: [String]
    public let currentFilePath: String?
    public let currentFileTarget: String?
    public let currentFileMatchedTargets: [String]
    public let currentFileIsInTarget: Bool
    public let isTargetMembershipResolved: Bool

    public init(
        projectPath: String,
        workspaceName: String,
        workspacePath: String,
        activeScheme: String?,
        activeSchemeBuildableTargets: [String],
        activeConfiguration: String?,
        activeDestination: String?,
        buildContextStatus: String,
        isXcodeProject: Bool,
        schemes: [String],
        configurations: [String],
        currentFilePath: String?,
        currentFileTarget: String?,
        currentFileMatchedTargets: [String],
        currentFileIsInTarget: Bool,
        isTargetMembershipResolved: Bool = false
    ) {
        self.projectPath = projectPath
        self.workspaceName = workspaceName
        self.workspacePath = workspacePath
        self.activeScheme = activeScheme
        self.activeSchemeBuildableTargets = activeSchemeBuildableTargets
        self.activeConfiguration = activeConfiguration
        self.activeDestination = activeDestination
        self.buildContextStatus = buildContextStatus
        self.isXcodeProject = isXcodeProject
        self.schemes = schemes
        self.configurations = configurations
        self.currentFilePath = currentFilePath
        self.currentFileTarget = currentFileTarget
        self.currentFileMatchedTargets = currentFileMatchedTargets
        self.currentFileIsInTarget = currentFileIsInTarget
        self.isTargetMembershipResolved = isTargetMembershipResolved
    }
}

/// 缓存状态快照（Sendable，供非主线程安全访问）
public struct BridgeCachedState: Sendable {
    public let workspaceFolders: [[String: String]]?
    public let buildServerPath: String?
    public let activeScheme: String?
    public let activeConfiguration: String?
    public let activeDestination: String?
    public let buildContextStatus: String
    public let isXcodeProject: Bool
    public let isInitialized: Bool
    public let workspaceName: String?
    public let workspacePath: String?
    public let schemes: [String]
    public let configurations: [String]
    public let projectPath: String?

    public init(
        workspaceFolders: [[String: String]]?,
        buildServerPath: String?,
        activeScheme: String?,
        activeConfiguration: String?,
        activeDestination: String?,
        buildContextStatus: String,
        isXcodeProject: Bool,
        isInitialized: Bool,
        workspaceName: String?,
        workspacePath: String?,
        schemes: [String],
        configurations: [String],
        projectPath: String?
    ) {
        self.workspaceFolders = workspaceFolders
        self.buildServerPath = buildServerPath
        self.activeScheme = activeScheme
        self.activeConfiguration = activeConfiguration
        self.activeDestination = activeDestination
        self.buildContextStatus = buildContextStatus
        self.isXcodeProject = isXcodeProject
        self.isInitialized = isInitialized
        self.workspaceName = workspaceName
        self.workspacePath = workspacePath
        self.schemes = schemes
        self.configurations = configurations
        self.projectPath = projectPath
    }
}
