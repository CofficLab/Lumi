import Foundation

/// 插件贡献（如 `agentTools`）收集失败时的承载结构。
///
/// 当某个插件在产出贡献时抛错，聚合层（`LumiPluginRegistry`）会捕获并把异常
/// 包装成本结构累积到副本属性，随后经 `AgentToolProviding.lastAgentToolFailures()`
/// 透传到 `AgentToolComponent.toolContributionFailures`，最终由 UI 在
/// 「设置 → 插件」详情页以红色 banner 呈现给用户。
///
/// 设计上放在 `LumiCoreKit`（内核最底层），与 `LumiToolRegistrationError` 同层；
/// UI 层只需依赖 `errorDescription`，无需感知具体哪个贡献点失败。
public struct LumiPluginContributionFailure: Sendable, Equatable {
    /// 失败插件的唯一标识（`LumiPluginInfo.id`）。
    public let pluginID: String

    /// 失败插件的显示名称（`LumiPluginInfo.displayName`），便于 UI 直接展示。
    public let pluginDisplayName: String

    /// 失败的贡献点标识（如 `"agentTools"`），用于定位是哪个聚合方法抛错。
    public let contribution: String

    /// 错误的本地化描述（原 error 的 `localizedDescription`）。
    public let errorDescription: String

    public init(
        pluginID: String,
        pluginDisplayName: String,
        contribution: String,
        errorDescription: String
    ) {
        self.pluginID = pluginID
        self.pluginDisplayName = pluginDisplayName
        self.contribution = contribution
        self.errorDescription = errorDescription
    }
}
