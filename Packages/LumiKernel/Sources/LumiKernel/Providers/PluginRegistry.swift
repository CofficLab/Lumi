import Foundation

/// 提供所有已注册插件列表的协议
///
/// 用于需要访问插件列表的服务，如 Theme 收集等。
@MainActor
public protocol PluginRegistry: AnyObject {
    /// 所有已注册的插件
    var allPlugins: [LumiPlugin] { get }

    /// 解析某个插件的"有效启用状态"(合并 policy 与用户覆盖)。
    func effectiveEnabled(for plugin: LumiPlugin) -> Bool

    /// 按 ID 查询插件是否处于有效启用状态。
    func isPluginEnabled(id: String) -> Bool

    /// 设置某个插件的启用状态(用户操作)。
    /// 仅对可配置插件生效;持久化并广播变更。
    func setPlugin(id: String, enabled: Bool)

    /// 清除某个插件的用户覆盖,回落到 policy 默认。
    func resetPlugin(id: String)
}

// MARK: - 默认实现(no-op,避免破坏尚不支持运行时启停的实现者)

public extension PluginRegistry {
    func effectiveEnabled(for plugin: LumiPlugin) -> Bool { plugin.policy.shouldRegister }
    func isPluginEnabled(id: String) -> Bool {
        allPlugins.contains { $0.id == id && effectiveEnabled(for: $0) }
    }
    func setPlugin(id: String, enabled: Bool) {}
    func resetPlugin(id: String) {}
}
