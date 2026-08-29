import Foundation

// MARK: - Plugin enable-state persistence

/// 插件启用状态的持久化契约。
///
/// KernelCore 不绑定具体的文件或 UserDefaults 实现；宿主负责注入存储。
@MainActor
public protocol PluginStatePersisting: AnyObject {
    /// 返回插件的持久化启用状态覆盖；`nil` 表示没有用户覆盖。
    func enabledState(pluginID: String) -> Bool?

    /// 保存插件启用状态。
    func setEnabled(_ enabled: Bool, pluginID: String)

    /// 删除插件的状态记录。
    func removeState(pluginID: String)
}
