import Foundation

/// 项目级配置选项。
public struct XcodeProjectOptions: Sendable {
    /// Xcode 兼容版本（如 "16.0"）。
    public let compatibilityVersion: String

    /// 项目格式版本（通常为 "Xcode 3.2 compatible"）。
    public let objectVersion: UInt

    /// 默认 Build Configuration 名称。
    public let defaultConfigurationName: String

    public init(
        compatibilityVersion: String = "16.0",
        objectVersion: UInt = 77,
        defaultConfigurationName: String = "Debug"
    ) {
        self.compatibilityVersion = compatibilityVersion
        self.objectVersion = objectVersion
        self.defaultConfigurationName = defaultConfigurationName
    }
}

/// Scheme 定义。
public struct XcodeSchemeSpec: Sendable {
    /// Scheme 名称。
    public let name: String

    /// 参与构建的 Target 名称列表。
    public let buildTargets: [String]

    /// 是否在构建前自动分析。
    public let analyze: Bool

    /// 运行时使用的 Configuration。
    public let runConfiguration: String

    /// 测试时使用的 Configuration。
    public let testConfiguration: String

    /// Profile 时使用的 Configuration。
    public let profileConfiguration: String

    /// 分析时使用的 Configuration。
    public let analyzeConfiguration: String

    /// Archive 时使用的 Configuration。
    public let archiveConfiguration: String

    public init(
        name: String,
        buildTargets: [String],
        analyze: Bool = true,
        runConfiguration: String = "Debug",
        testConfiguration: String = "Debug",
        profileConfiguration: String = "Release",
        analyzeConfiguration: String = "Debug",
        archiveConfiguration: String = "Release"
    ) {
        self.name = name
        self.buildTargets = buildTargets
        self.analyze = analyze
        self.runConfiguration = runConfiguration
        self.testConfiguration = testConfiguration
        self.profileConfiguration = profileConfiguration
        self.analyzeConfiguration = analyzeConfiguration
        self.archiveConfiguration = archiveConfiguration
    }
}

/// Xcode 项目配置声明。
///
/// 这是 `XcodeProjectGen` 的核心输入模型。通过声明式 API 描述完整的项目结构，
/// 再由 `XcodeProjectGenerator` 生成 `.xcodeproj`。
///
/// ```swift
/// let spec = XcodeProjectSpec(
///     name: "Cisum",
///     targets: [
///         .app(
///             name: "Cisum",
///             platform: .iOS,
///             deploymentTarget: "17.0",
///             sources: ["Sources/Cisum"],
///             dependencies: [
///                 .local(path: "Packages/PluginAudioControl", product: "PluginAudioControl")
///             ],
///             settings: [
///                 .bundleIdentifier("com.cofficlab.Cisum"),
///                 .developmentTeam("ABC123")
///             ]
///         ),
///         .framework(
///             name: "CisumCore",
///             sources: ["Sources/CisumCore"]
///         )
///     ],
///     schemes: [
///         XcodeSchemeSpec(name: "Cisum", buildTargets: ["Cisum"])
///     ]
/// )
/// ```
public struct XcodeProjectSpec: Sendable {
    /// 项目名称（同时也是 `.xcodeproj` 的文件名）。
    public let name: String

    /// 项目级 Build Settings（应用到所有 Target）。
    public let settings: [XcodeBuildSetting]

    /// 项目级 Build Configurations。
    public let configurations: [XcodeBuildConfigurationSpec]

    /// 项目选项。
    public let options: XcodeProjectOptions

    /// Target 列表。
    public let targets: [XcodeTargetSpec]

    /// Scheme 列表。如果为空，Generator 会为每个 App Target 自动生成一个 Scheme。
    public let schemes: [XcodeSchemeSpec]

    public init(
        name: String,
        settings: [XcodeBuildSetting] = [],
        configurations: [XcodeBuildConfigurationSpec] = [],
        options: XcodeProjectOptions = XcodeProjectOptions(),
        targets: [XcodeTargetSpec],
        schemes: [XcodeSchemeSpec] = []
    ) {
        self.name = name
        self.settings = settings
        self.configurations = configurations
        self.options = options
        self.targets = targets
        self.schemes = schemes
    }
}

// MARK: - 查询

extension XcodeProjectSpec {
    /// 按名称查找 Target。
    public func target(name: String) -> XcodeTargetSpec? {
        targets.first { $0.name == name }
    }

    /// 所有 App 类型的 Target。
    public var appTargets: [XcodeTargetSpec] {
        targets.filter { $0.kind == .app }
    }

    /// 所有 Framework 类型的 Target。
    public var frameworkTargets: [XcodeTargetSpec] {
        targets.filter { $0.kind == .framework }
    }

    /// 所有测试 Target。
    public var testTargets: [XcodeTargetSpec] {
        targets.filter { $0.kind == .unitTestBundle || $0.kind == .uiTestBundle }
    }

    /// 收集所有远程依赖（去重）。
    public var remoteDependencies: [XcodeDependencySpec] {
        var seen = Set<String>()
        return targets.flatMap { $0.dependencies }.compactMap { dep in
            if case .remote(let url, _, _) = dep {
                if seen.insert(url).inserted {
                    return dep
                }
            }
            return nil
        }
    }

    /// 收集所有本地依赖（去重）。
    public var localDependencies: [XcodeDependencySpec] {
        var seen = Set<String>()
        return targets.flatMap { $0.dependencies }.compactMap { dep in
            if case .local(let path, _) = dep {
                if seen.insert(path).inserted {
                    return dep
                }
            }
            return nil
        }
    }
}
