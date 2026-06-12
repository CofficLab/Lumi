import Foundation

// MARK: - Xcode Destination Context

/// 代表一个构建目标（设备/模拟器/macOS）
public struct XcodeDestinationContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let platform: String
    public let arch: String?
    public let name: String
    public let destinationQuery: String

    public init(
        id: String,
        platform: String,
        arch: String?,
        name: String,
        destinationQuery: String
    ) {
        self.id = id
        self.platform = platform
        self.arch = arch
        self.name = name
        self.destinationQuery = destinationQuery
    }

    public static func == (lhs: XcodeDestinationContext, rhs: XcodeDestinationContext) -> Bool {
        lhs.id == rhs.id
    }

    public static func macOSDefault(arch: String? = "arm64") -> XcodeDestinationContext {
        XcodeDestinationContext(
            id: "macOS-\(arch ?? "default")",
            platform: "macOS",
            arch: arch,
            name: arch.map { "My Mac (\($0))" } ?? "My Mac",
            destinationQuery: arch.map { "platform=macOS,arch=\($0)" } ?? "platform=macOS"
        )
    }
}

// MARK: - Xcode Build Configuration Context

/// 代表一个 Build Configuration（Debug / Release）
public struct XcodeBuildConfigurationContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public var settings: [String: String] = [:]

    public init(id: String, name: String, settings: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.settings = settings
    }

    public static func == (lhs: XcodeBuildConfigurationContext, rhs: XcodeBuildConfigurationContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Target Context

/// 代表一个 Xcode Target
public struct XcodeTargetContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let productType: String?
    public let buildConfigurations: [XcodeBuildConfigurationContext]
    public let sourceFiles: Set<String>  // 文件绝对路径集合

    public init(
        id: String,
        name: String,
        productType: String?,
        buildConfigurations: [XcodeBuildConfigurationContext],
        sourceFiles: Set<String>
    ) {
        self.id = id
        self.name = name
        self.productType = productType
        self.buildConfigurations = buildConfigurations
        self.sourceFiles = sourceFiles
    }

    public static func == (lhs: XcodeTargetContext, rhs: XcodeTargetContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Scheme Context

/// 代表一个 Xcode Scheme，绑定 active target / configuration / destination
public struct XcodeSchemeContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let buildableTargets: [String]  // target names
    public let defaultConfiguration: String?
    public var activeConfiguration: String = "Debug"
    public var activeDestination: XcodeDestinationContext?

    public init(
        id: String,
        name: String,
        buildableTargets: [String],
        defaultConfiguration: String?,
        activeConfiguration: String = "Debug",
        activeDestination: XcodeDestinationContext? = nil
    ) {
        self.id = id
        self.name = name
        self.buildableTargets = buildableTargets
        self.defaultConfiguration = defaultConfiguration
        self.activeConfiguration = activeConfiguration
        self.activeDestination = activeDestination
    }

    public static func == (lhs: XcodeSchemeContext, rhs: XcodeSchemeContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Project Context

/// 代表一个 .xcodeproj
public struct XcodeProjectContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: URL
    public let targets: [XcodeTargetContext]
    public let buildConfigurations: [XcodeBuildConfigurationContext]
    public let schemes: [XcodeSchemeContext]

    public init(
        id: String,
        name: String,
        path: URL,
        targets: [XcodeTargetContext],
        buildConfigurations: [XcodeBuildConfigurationContext],
        schemes: [XcodeSchemeContext]
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.targets = targets
        self.buildConfigurations = buildConfigurations
        self.schemes = schemes
    }

    public static func == (lhs: XcodeProjectContext, rhs: XcodeProjectContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Workspace Context

/// 代表一个 .xcworkspace（可能包含多个 projects）
public struct XcodeWorkspaceContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: URL
    public let projects: [XcodeProjectContext]
    public let schemes: [XcodeSchemeContext]
    public var activeScheme: XcodeSchemeContext?
    public var activeDestination: XcodeDestinationContext?

    public init(
        id: String,
        name: String,
        path: URL,
        projects: [XcodeProjectContext],
        schemes: [XcodeSchemeContext],
        activeScheme: XcodeSchemeContext? = nil,
        activeDestination: XcodeDestinationContext? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.projects = projects
        self.schemes = schemes
        self.activeScheme = activeScheme
        self.activeDestination = activeDestination
    }

    /// 工作空间根目录（去掉 .xcworkspace 后缀后的目录）
    public var rootURL: URL {
        let pathStr = path.path
        if pathStr.hasSuffix(".xcworkspace") {
            return path.deletingLastPathComponent()
        }
        return path
    }

    public static func == (lhs: XcodeWorkspaceContext, rhs: XcodeWorkspaceContext) -> Bool {
        lhs.id == rhs.id
    }
}
