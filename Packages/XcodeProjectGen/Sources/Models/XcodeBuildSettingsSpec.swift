import Foundation

/// 构建设置声明。
///
/// 提供两种使用方式：
/// 1. 使用预定义的便捷方法（类型安全）
/// 2. 使用 `custom(key:value:)` 设置任意 Build Setting
public enum XcodeBuildSetting: Sendable {
    // MARK: - Identity

    /// Bundle Identifier。
    case bundleIdentifier(_ value: String)
    /// 产品名称。
    case productName(_ value: String)
    /// 产品模块名称。
    case moduleIdentifier(_ value: String)
    /// 开发者 Team ID。
    case developmentTeam(_ value: String)

    // MARK: - Platform & SDK

    /// 部署目标版本。
    case deploymentTarget(_ value: String)
    /// 目标设备族。
    case targetedDeviceFamily(_ value: String)

    // MARK: - Swift Compiler

    /// Swift 语言版本。
    case swiftVersion(_ value: String)
    /// 启用的 Swift 编译条件（DEBUG 标志等）。
    case activeCompilationConditions(_ value: String)

    // MARK: - Signing

    /// 代码签名风格：Automatic 或 Manual。
    case codeSignStyle(_ value: String)
    /// 代码签名证书名称。
    case codeSignIdentity(_ value: String)
    /// Entitlements 文件路径。
    case entitlementsPath(_ value: String)
    /// Info.plist 文件路径。
    case infoPlistPath(_ value: String)

    // MARK: - Optimization

    /// 优化级别。
    case optimizationLevel(_ value: String)
    /// 是否启用 Whole Module Optimization。
    case wholeModuleOptimization(_ enabled: Bool)

    // MARK: - Custom

    /// 自定义 Build Setting。
    case custom(key: String, value: String)

    // MARK: - 键值提取

    /// 转换为 Xcode Build Setting 的键值对。
    public var keyValue: (key: String, value: String) {
        switch self {
        // Identity
        case .bundleIdentifier(let v): return ("PRODUCT_BUNDLE_IDENTIFIER", v)
        case .productName(let v): return ("PRODUCT_NAME", v)
        case .moduleIdentifier(let v): return ("PRODUCT_MODULE_NAME", v)
        case .developmentTeam(let v): return ("DEVELOPMENT_TEAM", v)

        // Platform & SDK
        case .deploymentTarget(let v): return ("DEPLOYMENT_TARGET_SETTING_NAME", v)
        case .targetedDeviceFamily(let v): return ("TARGETED_DEVICE_FAMILY", v)

        // Swift Compiler
        case .swiftVersion(let v): return ("SWIFT_VERSION", v)
        case .activeCompilationConditions(let v): return ("ACTIVE_COMPILATION_CONDITIONS", v)

        // Signing
        case .codeSignStyle(let v): return ("CODE_SIGN_STYLE", v)
        case .codeSignIdentity(let v): return ("CODE_SIGN_IDENTITY", v)
        case .entitlementsPath(let v): return ("CODE_SIGN_ENTITLEMENTS", v)
        case .infoPlistPath(let v): return ("INFOPLIST_FILE", v)

        // Optimization
        case .optimizationLevel(let v): return ("SWIFT_OPTIMIZATION_LEVEL", v)
        case .wholeModuleOptimization(let v): return ("WHOLE_MODULE_OPTIMIZATION", v ? "YES" : "NO")

        // Custom
        case .custom(let k, let v): return (k, v)
        }
    }
}

/// Build Configuration（Debug / Release）的自定义设置。
public struct XcodeBuildConfigurationSpec: Sendable {
    /// 配置名称（如 "Debug"、"Release"）。
    public let name: String
    /// 该配置下的 Build Settings。
    public let settings: [XcodeBuildSetting]

    public init(name: String, settings: [XcodeBuildSetting] = []) {
        self.name = name
        self.settings = settings
    }

    /// 便捷：Debug 配置。
    public static func debug(settings: [XcodeBuildSetting] = []) -> XcodeBuildConfigurationSpec {
        XcodeBuildConfigurationSpec(name: "Debug", settings: settings)
    }

    /// 便捷：Release 配置。
    public static func release(settings: [XcodeBuildSetting] = []) -> XcodeBuildConfigurationSpec {
        XcodeBuildConfigurationSpec(name: "Release", settings: settings)
    }
}
