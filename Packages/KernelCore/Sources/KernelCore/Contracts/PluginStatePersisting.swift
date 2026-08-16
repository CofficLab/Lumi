import Foundation

// MARK: - Plugin enable-state persistence

/// 插件启用状态的持久化契约。
///
/// KernelCore 保持零依赖，不直接绑定 UserDefaults/文件存储；宿主或上层
/// （如 FactoryLumi2 / LumiMinimalApp）注入实现。存储 key 与 schema 由实现方决定。
@MainActor
public protocol PluginStatePersisting: AnyObject {
    /// 返回插件持久化的启用状态覆盖；`nil` 表示无记录，使用插件默认策略。
    func enabledState(pluginID: String) -> Bool?
    /// 保存插件启用状态。
    func setEnabled(_ enabled: Bool, pluginID: String)
    /// 删除插件的状态记录（插件卸载/停用时可选调用）。
    func removeState(pluginID: String)
}

/// 基于 UserDefaults 的默认实现。
///
/// 使用带版本前缀的 key（`lumi.kernel.plugin-state.v1.<id>`），便于后续
/// schema 演进；同一 id 的读写是幂等的。
@MainActor
public final class UserDefaultsPluginStateStore: PluginStatePersisting {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "lumi.kernel.plugin-state.v1") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    private func key(_ pluginID: String) -> String { "\(keyPrefix).\(pluginID)" }

    public func enabledState(pluginID: String) -> Bool? {
        defaults.object(forKey: key(pluginID)) as? Bool
    }

    public func setEnabled(_ enabled: Bool, pluginID: String) {
        defaults.set(enabled, forKey: key(pluginID))
    }

    public func removeState(pluginID: String) {
        defaults.removeObject(forKey: key(pluginID))
    }
}
