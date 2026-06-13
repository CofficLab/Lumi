import SwiftUI

/// Logo 注册表
///
/// 收集所有插件贡献的 ``LumiLogoItem``，按 ``LumiLogoItem/order`` 选出全局最高优先级的 Logo。
/// 无插件贡献时 ``LogoView`` 回退到内置的 ``SmartLightLogo``。
///
/// 由 ``PluginService`` 在插件加载时调用 ``register(_:)`` 完成注册。
@MainActor
public final class LogoRegistry: ObservableObject {
    /// 全局共享实例
    @MainActor public static let shared = LogoRegistry()

    /// 当前最高优先级的 Logo 项（已缓存，注册时刷新）
    @Published private(set) public var bestItem: LumiLogoItem?

    private init() {}

    /// 批量注册 Logo 项，保留 order 最高的一项
    ///
    /// - Parameter items: 来自各插件的 Logo 贡献
    public func register(_ items: [LumiLogoItem]) {
        bestItem = items.max(by: { $0.order < $1.order })
    }
}
