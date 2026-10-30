import Foundation

/// 与 `UserDefaults.standard` 物理隔离的偏好实例。
///
/// ## 背景
///
/// 部分代码把配置写在 `UserDefaults.standard`（例如 `KitKeychain` 的 legacy
/// 迁移通道、`PluginAppUpdate` 的更新通道）。标准域是**用户级全局状态**：
///
/// - 测试写入会留到用户下次启动，污染真实配置；
/// - 用户残留的值会让断言随机失败——这正是「测试不稳定」最常见的来源，
///   且失败点漂移（取决于用户上次用了什么），几乎无法复现。
///
/// ## 用法
///
/// ```swift
/// let defaults = IsolatedUserDefaults(prefix: "app-update")
/// defer { defaults.reset() }
/// defaults.set("preview", forKey: AppUpdateChannel.userDefaultsKey)
/// ```
///
/// 每个实例使用 `suiteName = <prefix>.<UUID>`，物理上是独立 domain，
/// 并在创建时 `removePersistentDomain`，因此即使同一进程内重复创建也不会继承残留。
public final class IsolatedUserDefaults: @unchecked Sendable {

    /// 隔离的 `UserDefaults` 实例。
    public let defaults: UserDefaults

    /// 对应的 suite 名（可用于清理）。
    public let suiteName: String

    private init(prefix: String) {
        let suiteName = "com.coffic.lumi.test.\(prefix).\(UUID().uuidString)"
        self.suiteName = suiteName
        // suiteName: 返回 nil 表示参数非法；测试里唯一的非法来源是本构造器，
        // 它的入参是内部生成的固定格式字符串。
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("无法创建隔离的 UserDefaults（suite: \(suiteName)）")
        }
        self.defaults = defaults
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// 创建隔离实例。
    ///
    /// - Parameter prefix: 用途前缀，仅用于可辨识性。
    public static func make(prefix: String) -> IsolatedUserDefaults {
        IsolatedUserDefaults(prefix: prefix)
    }

    /// 读取值。
    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    /// 写入值。
    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    /// 删除值。
    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// 彻底清空并释放 domain（磁盘上的 plist 一并删除）。
    ///
    /// 调用后本实例不应再使用——domain 已消失，写入会静默失效。
    public func reset() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }
}