import Foundation

/// 插件准入资格：封装注册/启用的判断逻辑
///
/// 将插件系统的三道关卡（注册 → 可配置 → 用户设置）内聚为一个值类型，
/// 外部只需调用 `shouldRegister` / `isEligible` 即可完成判断，无需关心内部细节。
///
/// ## 三道关卡
///
/// 1. **shouldRegister** — 扫描门槛，由插件静态属性 `shouldRegister` 控制
/// 2. **isConfigurable** — 是否允许用户切换，不可配置的插件始终启用
/// 3. **userEnabled** — 用户在设置中实际配置的启用状态（或 `enabledByDefault` 默认值）
///
/// ## 使用示例
///
/// ```swift
/// // 构造
/// let eligibility = PluginEligibility(
///     shouldRegister: pluginType.shouldRegister,
///     isConfigurable: pluginType.isConfigurable,
///     enabledByDefault: pluginType.enabledByDefault,
///     userEnabled: settingsStore.isPluginEnabled(pluginId, defaultEnabled: pluginType.enabledByDefault)
/// )
///
/// // 判断：是否应该注册到系统
/// if eligibility.shouldRegister { ... }
///
/// // 判断：是否具备参与 UI 贡献的资格（已注册 + 已启用）
/// if eligibility.isEligible { ... }
/// ```
public struct PluginEligibility: Equatable, Sendable {

    // MARK: - 存储属性

    /// 第一关：是否应被系统扫描和注册
    ///
    /// - `true`：插件进入注册流程
    /// - `false`：插件在扫描阶段直接跳过（开发中 / 已废弃）
    public let shouldRegister: Bool

    /// 第二关：是否允许用户在设置中切换启用状态
    ///
    /// - `true`：用户可以在设置面板中开关此插件
    /// - `false`：插件始终启用，忽略用户设置
    public let isConfigurable: Bool

    /// 插件的默认启用状态（仅当 `isConfigurable = true` 时有意义）
    ///
    /// 作为用户未手动配置时的回退值。
    public let enabledByDefault: Bool

    /// 第三关：用户实际配置的启用状态
    ///
    /// 由 `AppPluginSettingsVM` 从持久化存储读取，
    /// 若用户未配置过则等于 `enabledByDefault`。
    public let userEnabled: Bool

    // MARK: - 派生属性

    /// 插件是否具备参与 UI 贡献的资格（已注册 + 已启用）
    ///
    /// 综合判断逻辑：
    /// ```
    /// if !shouldRegister → false（未注册）
    /// if !isConfigurable → true（不可配置 = 始终启用）
    /// → userEnabled（可配置 = 看用户设置）
    /// ```
    public var isEligible: Bool {
        guard shouldRegister else { return false }
        guard isConfigurable else { return true }
        return userEnabled
    }

    /// 是否应该出现在插件设置页面
    ///
    /// 需要同时满足：已注册 + 可配置。
    public var appearsInSettings: Bool {
        shouldRegister && isConfigurable
    }

    // MARK: - Init

    public init(
        shouldRegister: Bool,
        isConfigurable: Bool,
        enabledByDefault: Bool,
        userEnabled: Bool
    ) {
        self.shouldRegister = shouldRegister
        self.isConfigurable = isConfigurable
        self.enabledByDefault = enabledByDefault
        self.userEnabled = userEnabled
    }

    /// 从 PluginPolicy 便捷构造
    ///
    /// - Parameters:
    ///   - policy: 插件的注册策略
    ///   - userEnabled: 用户在设置中实际配置的启用状态
    public init(policy: PluginPolicy, userEnabled: Bool) {
        self.shouldRegister = policy != .disabled
        self.isConfigurable = (policy == .optOut || policy == .optIn)
        self.enabledByDefault = (policy == .alwaysOn || policy == .optOut)
        self.userEnabled = userEnabled
    }
}
