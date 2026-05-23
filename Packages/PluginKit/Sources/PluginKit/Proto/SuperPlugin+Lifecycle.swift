import Foundation

// MARK: - Lifecycle Default Implementation

extension SuperPlugin {
    /// 默认实现：插件注册后无操作
    nonisolated public func onRegister() {}

    /// 默认实现：插件启用后无操作
    nonisolated public func onEnable() {}

    /// 默认实现：插件禁用后无操作
    nonisolated public func onDisable() {}

    /// 默认实现：插件注册顺序为 999
    public static var order: Int { 999 }
}
