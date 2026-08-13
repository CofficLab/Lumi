import Foundation

/// 插件启用策略
///
/// 定义插件的启用行为和用户可配置性。
public enum LumiPluginPolicy: String, Sendable, Codable, CaseIterable {
    /// 始终启用，不可禁用
    case alwaysOn

    /// 默认启用，用户可选择禁用
    case optOut

    /// 默认禁用，用户可选择启用
    case optIn

    /// 禁用，不可启用
    case disabled

    /// 是否应该注册此插件
    public var shouldRegister: Bool {
        self != .disabled
    }

    /// 用户是否可配置此插件的启用状态
    public var isConfigurable: Bool {
        switch self {
        case .optOut, .optIn:
            true
        case .alwaysOn, .disabled:
            false
        }
    }

    /// 默认是否启用
    public var enabledByDefault: Bool {
        switch self {
        case .alwaysOn, .optOut:
            true
        case .optIn, .disabled:
            false
        }
    }
}