import Foundation

/// Target 配置声明。
///
/// 定义一个 Xcode Target 的所有属性：类型、平台、源文件、依赖、构建设置等。
///
/// ```swift
/// let target = XcodeTargetSpec(
///     name: "MyApp",
///     kind: .app,
///     platform: .iOS,
///     deploymentTarget: "17.0",
///     sources: ["Sources/MyApp"],
///     resources: ["Resources"],
///     dependencies: [
///         .local(path: "Packages/MyCore", product: "MyCore"),
///         .remote(url: "https://github.com/...", product: "Alamofire", versionRequirement: .upToNextMajor("5.0.0"))
///     ],
///     settings: [
///         .bundleIdentifier("com.example.MyApp"),
///         .developmentTeam("ABC123"),
///         .infoPlistPath("MyApp/Info.plist")
///     ]
/// )
/// ```
public struct XcodeTargetSpec: Sendable {
    /// Target 名称。
    public let name: String

    /// Target 产品类型。
    public let kind: XcodeTargetKind

    /// 目标平台。
    public let platform: XcodePlatform

    /// 最低部署目标版本（如 "17.0"）。
    public let deploymentTarget: String

    /// 源文件目录或文件路径（相对于项目根目录）。
    /// 支持目录（自动递归扫描 .swift 文件）和单文件。
    public let sources: [String]

    /// 资源文件目录或文件路径（相对于项目根目录）。
    /// 支持 `.xcassets`、`.strings`、`.xib`、`.storyboard` 等。
    public let resources: [String]

    /// 依赖列表。
    public let dependencies: [XcodeDependencySpec]

    /// Build Settings（全局，同时应用到 Debug 和 Release）。
    public let settings: [XcodeBuildSetting]

    /// 按 Configuration 区分的 Build Settings。
    public let configurations: [XcodeBuildConfigurationSpec]

    /// Entitlements 文件路径（相对于项目根目录）。
    public let entitlementsPath: String?

    /// Info.plist 文件路径（相对于项目根目录）。
    public let infoPlistPath: String?

    public init(
        name: String,
        kind: XcodeTargetKind,
        platform: XcodePlatform = .iOS,
        deploymentTarget: String = "17.0",
        sources: [String] = [],
        resources: [String] = [],
        dependencies: [XcodeDependencySpec] = [],
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        entitlementsPath: String? = nil,
        infoPlistPath: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.platform = platform
        self.deploymentTarget = deploymentTarget
        self.sources = sources
        self.resources = resources
        self.dependencies = dependencies
        self.settings = settings
        self.configurations = configurations
        self.entitlementsPath = entitlementsPath
        self.infoPlistPath = infoPlistPath
    }
}

// MARK: - 便捷 Target 工厂方法

extension XcodeTargetSpec {
    /// 创建一个 App Target。
    public static func app(
        name: String,
        platform: XcodePlatform = .iOS,
        deploymentTarget: String = "17.0",
        sources: [String] = [],
        resources: [String] = [],
        dependencies: [XcodeDependencySpec] = [],
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        entitlementsPath: String? = nil,
        infoPlistPath: String? = nil
    ) -> XcodeTargetSpec {
        XcodeTargetSpec(
            name: name,
            kind: .app,
            platform: platform,
            deploymentTarget: deploymentTarget,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: settings,
            configurations: configurations,
            entitlementsPath: entitlementsPath,
            infoPlistPath: infoPlistPath
        )
    }

    /// 创建一个 Framework Target。
    public static func framework(
        name: String,
        platform: XcodePlatform = .iOS,
        deploymentTarget: String = "17.0",
        sources: [String] = [],
        resources: [String] = [],
        dependencies: [XcodeDependencySpec] = [],
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = []
    ) -> XcodeTargetSpec {
        XcodeTargetSpec(
            name: name,
            kind: .framework,
            platform: platform,
            deploymentTarget: deploymentTarget,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: settings,
            configurations: configurations
        )
    }

    /// 创建一个单元测试 Target。
    public static func unitTest(
        name: String,
        platform: XcodePlatform = .iOS,
        deploymentTarget: String = "17.0",
        sources: [String] = [],
        dependencies: [XcodeDependencySpec] = [],
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        targetDependency: String? = nil
    ) -> XcodeTargetSpec {
        var deps = dependencies
        if let targetDependency {
            deps.append(.target(name: targetDependency))
        }
        return XcodeTargetSpec(
            name: name,
            kind: .unitTestBundle,
            platform: platform,
            deploymentTarget: deploymentTarget,
            sources: sources,
            dependencies: deps,
            settings: settings,
            configurations: configurations
        )
    }

    /// 创建一个 App Extension Target。
    public static func appExtension(
        name: String,
        platform: XcodePlatform = .iOS,
        deploymentTarget: String = "17.0",
        sources: [String] = [],
        resources: [String] = [],
        dependencies: [XcodeDependencySpec] = [],
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        entitlementsPath: String? = nil,
        infoPlistPath: String? = nil
    ) -> XcodeTargetSpec {
        XcodeTargetSpec(
            name: name,
            kind: .appExtension,
            platform: platform,
            deploymentTarget: deploymentTarget,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: settings,
            configurations: configurations,
            entitlementsPath: entitlementsPath,
            infoPlistPath: infoPlistPath
        )
    }
}
