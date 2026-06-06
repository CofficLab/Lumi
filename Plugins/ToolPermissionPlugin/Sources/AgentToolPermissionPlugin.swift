import LumiCoreKit

/// 工具执行授权浮层：在根视图上叠加 `PermissionRequestView`，与聊天区域解耦。
public actor AgentToolPermissionPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let emoji = "🔐"
    public nonisolated static let verbose: Bool = false
    public static let id = "AgentToolPermission"
    public static let displayName = String(localized: "Tool Permission", bundle: .module)
    public static let description = String(localized: "Tool permission overlay at root", bundle: .module)
    public static let iconName = "lock.shield"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 95 }

    public static let shared = AgentToolPermissionPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

}
