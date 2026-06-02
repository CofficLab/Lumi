import Foundation

/// Apple 平台类型，用于 Target 部署目标声明。
public enum XcodePlatform: String, Sendable, Codable, CaseIterable {
    case iOS
    case macOS
    case tvOS
    case watchOS
    case visionOS

    /// 对应 Xcode Build Settings 中的 SDKROOT 值。
    public var sdkRoot: String {
        switch self {
        case .iOS: return "iphoneos"
        case .macOS: return "macosx"
        case .tvOS: return "appletvos"
        case .watchOS: return "watchos"
        case .visionOS: return "xros"
        }
    }

    /// 对应 Xcode Build Settings 中的 TARGETED_DEVICE_FAMILY 值。
    public var targetedDeviceFamily: String? {
        switch self {
        case .iOS: return "1,2"
        case .macOS: return nil
        case .tvOS: return "3"
        case .watchOS: return "4"
        case .visionOS: return "1,2,7"
        }
    }

    /// 对应 SUPPORTS_MACCATALYST。
    public var supportsMacCatalyst: Bool {
        switch self {
        case .iOS: return true
        default: return false
        }
    }

    /// 部署目标 Build Setting 键名。
    public var deploymentTargetKey: String {
        switch self {
        case .iOS: return "IPHONEOS_DEPLOYMENT_TARGET"
        case .macOS: return "MACOSX_DEPLOYMENT_TARGET"
        case .tvOS: return "TVOS_DEPLOYMENT_TARGET"
        case .watchOS: return "WATCHOS_DEPLOYMENT_TARGET"
        case .visionOS: return "XROS_DEPLOYMENT_TARGET"
        }
    }
}
