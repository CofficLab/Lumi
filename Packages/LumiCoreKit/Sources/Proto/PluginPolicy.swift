/// 插件注册策略
///
/// 控制插件的注册与启用行为，取代旧的 enable / isConfigurable / shouldRegister / enabledByDefault 组合。
///
/// | Policy      | shouldRegister | isConfigurable | enabledByDefault | 说明                         |
/// |-------------|----------------|----------------|------------------|------------------------------|
/// | `.alwaysOn` | true           | false          | true             | 始终启用，用户不可关闭       |
/// | `.optOut`   | true           | true           | true             | 默认启用，用户可关闭         |
/// | `.optIn`    | true           | true           | false            | 默认关闭，用户可开启         |
/// | `.disabled` | false          | —              | —                | 不注册，开发中 / 已废弃      |
public enum PluginPolicy: String, Sendable, Codable {
    /// 始终启用，用户不可关闭
    case alwaysOn
    /// 默认启用，用户可关闭
    case optOut
    /// 默认关闭，用户可开启
    case optIn
    /// 不注册（开发中 / 已废弃）
    case disabled
}
