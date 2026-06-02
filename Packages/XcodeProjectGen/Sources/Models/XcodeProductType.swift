import Foundation

/// Target 产品类型。
public enum XcodeProductType: String, Sendable, Codable {
    /// iOS / macOS / tvOS / watchOS / visionOS 应用。
    case application = "com.apple.product-type.application"
    /// Framework 动态库。
    case framework = "com.apple.product-type.framework"
    /// 静态库。
    case staticLibrary = "com.apple.product-type.library.static"
    /// 动态库。
    case dynamicLibrary = "com.apple.product-type.library.dynamic"
    /// 单元测试 Bundle。
    case unitTestBundle = "com.apple.product-type.bundle.unit-test"
    /// UI 测试 Bundle。
    case uiTestBundle = "com.apple.product-type.bundle.ui-testing"
    /// App Extension（Share、Today、Widget 等）。
    case appExtension = "com.apple.product-type.app-extension"
    /// Extension Kit Extension。
    case extensionKitExtension = "com.apple.product-type.extensionkit-extension"
    /// XPC Service。
    case xpcService = "com.apple.product-type.xpc-service"
    /// Bundle / Resource。
    case bundle = "com.apple.product-type.bundle"
    /// 命令行工具。
    case tool = "com.apple.product-type.tool"

    /// XcodeProj 中对应的 PBXProductType 枚举原始值。
    public var pbxProductType: String {
        return rawValue
    }
}

// MARK: - Target 类型便捷构造

/// 用于声明式定义 Target 类别的枚举。
public enum XcodeTargetKind: Sendable {
    /// 应用程序。
    case app
    /// Framework 动态库。
    case framework
    /// 静态库。
    case staticLibrary
    /// 单元测试。
    case unitTestBundle
    /// UI 测试。
    case uiTestBundle
    /// App Extension。
    case appExtension
    /// Extension Kit Extension。
    case extensionKitExtension
    /// 命令行工具（仅 macOS）。
    case tool

    /// 映射到 XcodeProductType。
    public var productType: XcodeProductType {
        switch self {
        case .app: return .application
        case .framework: return .framework
        case .staticLibrary: return .staticLibrary
        case .unitTestBundle: return .unitTestBundle
        case .uiTestBundle: return .uiTestBundle
        case .appExtension: return .appExtension
        case .extensionKitExtension: return .extensionKitExtension
        case .tool: return .tool
        }
    }
}
