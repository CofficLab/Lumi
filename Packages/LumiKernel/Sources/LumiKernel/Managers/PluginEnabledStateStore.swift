import Foundation

/// 插件启用状态持久化存储
///
/// 保存用户对每个可配置插件(`policy.isConfigurable == true`)的启用/禁用覆盖。
/// 以 `[pluginID: Bool]` 形式存入 `UserDefaults`,跨启动保留。
///
/// 有效启用状态由 `BuiltinPluginManager.effectiveEnabled(for:)` 解析:
/// - `alwaysOn`:始终启用,忽略覆盖
/// - `disabled`:始终禁用,忽略覆盖
/// - `optOut` / `optIn`:读取覆盖,缺省时回落到 `policy.enabledByDefault`
@MainActor
final class PluginEnabledStateStore {
    /// UserDefaults 键
    private let storageKey = "com.coffic.lumi.pluginEnabledOverrides"

    /// 内存缓存,启动时一次性载入,避免每次查询都走磁盘
    private var cache: [String: Bool]

    init() {
        cache = Self.load(key: storageKey)
    }

    /// 读取某个插件的用户覆盖值;`nil` 表示用户未设置(应回落到默认)。
    func override(for id: String) -> Bool? {
        cache[id]
    }

    /// 设置某个插件的用户覆盖值并持久化。
    func setOverride(_ enabled: Bool, for id: String) {
        cache[id] = enabled
        persist()
    }

    /// 清除某个插件的用户覆盖值(回落到默认)。
    func clearOverride(for id: String) {
        cache.removeValue(forKey: id)
        persist()
    }

    /// 所有当前的用户覆盖快照。
    func allOverrides() -> [String: Bool] {
        cache
    }

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        if cache.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(cache, forKey: storageKey)
        }
    }

    private static func load(key: String) -> [String: Bool] {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] else {
            return [:]
        }
        return dict
    }
}
