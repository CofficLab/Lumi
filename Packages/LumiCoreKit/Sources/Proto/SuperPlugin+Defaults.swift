import AgentToolKit
import Foundation

// MARK: - Core Property Default Implementation

extension SuperPlugin {
    /// 自动派生插件 ID（类名去掉 "Plugin" 后缀）
    public static var id: String {
        String(describing: self)
            .replacingOccurrences(of: "Plugin", with: "")
    }

    nonisolated public var instanceLabel: String { Self.id }

    public static var displayName: String { id }

    public static var description: String { "" }

    public static func description(for language: LanguagePreference) -> String {
        description
    }

    public static var iconName: String { "puzzlepiece" }

    /// 默认策略：禁用，插件需要显式切换策略后才会注册。
    public static var policy: PluginPolicy { .disabled }

    public static var isConfigurable: Bool {
        switch policy {
        case .alwaysOn, .disabled: return false
        case .optOut, .optIn: return true
        }
    }

    @available(*, deprecated, message: "Use policy instead.")
    public static var enable: Bool { enabledByDefault }

    public static var shouldRegister: Bool { policy != .disabled }

    public static var enabledByDefault: Bool {
        switch policy {
        case .alwaysOn, .optOut: return true
        case .optIn, .disabled: return false
        }
    }
}
