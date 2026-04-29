import Foundation

// MARK: - Xcode Destination Context

/// 代表一个构建目标（设备/模拟器/macOS）
struct XcodeDestinationContext: Identifiable, Equatable {
    let id: String
    let platform: String
    let arch: String?
    let name: String

    static func == (lhs: XcodeDestinationContext, rhs: XcodeDestinationContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Build Configuration Context

/// 代表一个 Build Configuration（Debug / Release）
struct XcodeBuildConfigurationContext: Identifiable, Equatable {
    let id: String
    let name: String
    var settings: [String: String] = [:]

    static func == (lhs: XcodeBuildConfigurationContext, rhs: XcodeBuildConfigurationContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Target Context

/// 代表一个 Xcode Target
struct XcodeTargetContext: Identifiable, Equatable {
    let id: String
    let name: String
    let productType: String?
    let buildConfigurations: [XcodeBuildConfigurationContext]
    let sourceFiles: Set<String>  // 文件相对路径集合

    static func == (lhs: XcodeTargetContext, rhs: XcodeTargetContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Scheme Context

/// 代表一个 Xcode Scheme，绑定 active target / configuration / destination
struct XcodeSchemeContext: Identifiable, Equatable {
    let id: String
    let name: String
    let buildableTargets: [String]  // target names
    let defaultConfiguration: String?
    var activeConfiguration: String = "Debug"
    var activeDestination: XcodeDestinationContext?

    static func == (lhs: XcodeSchemeContext, rhs: XcodeSchemeContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Project Context

/// 代表一个 .xcodeproj
struct XcodeProjectContext: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let targets: [XcodeTargetContext]
    let buildConfigurations: [XcodeBuildConfigurationContext]
    let schemes: [XcodeSchemeContext]

    static func == (lhs: XcodeProjectContext, rhs: XcodeProjectContext) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Xcode Workspace Context

/// 代表一个 .xcworkspace（可能包含多个 projects）
struct XcodeWorkspaceContext: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let projects: [XcodeProjectContext]
    let schemes: [XcodeSchemeContext]
    var activeScheme: XcodeSchemeContext?
    var activeDestination: XcodeDestinationContext?

    /// 工作空间根目录（去掉 .xcworkspace 后缀后的目录）
    var rootURL: URL {
        let pathStr = path.path
        if pathStr.hasSuffix(".xcworkspace") {
            return path.deletingLastPathComponent()
        }
        return path
    }

    static func == (lhs: XcodeWorkspaceContext, rhs: XcodeWorkspaceContext) -> Bool {
        lhs.id == rhs.id
    }
}
