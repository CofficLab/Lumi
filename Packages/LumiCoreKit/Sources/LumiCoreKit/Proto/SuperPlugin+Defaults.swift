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

    public static var iconName: String { "puzzlepiece" }

    public static var isConfigurable: Bool { false }

    @available(*, deprecated, message: "Use enabledByDefault instead. This property will be removed in a future version.")
    public static var enable: Bool { enabledByDefault }

    public static var shouldRegister: Bool { true }

    public static var enabledByDefault: Bool { true }
}
