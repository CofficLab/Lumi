import Foundation

/// 插件贡献（如 `agentTools`）收集失败时的承载结构。
///
/// 当某个插件在产出贡献时抛错,聚合层会捕获并把异常包装成本结构累积到副本属性,
/// 随后经 `AgentToolProviding.lastAgentToolFailures()` 透传到
/// `AgentToolComponent.toolContributionFailures`,最终由 UI 在「设置 → 插件」详情页
/// 以红色 banner 呈现给用户。
///
/// 设计上放在 LumiKernel (内核最底层),与 `LumiToolRegistrationError` 同层;
/// UI 层只需依赖 `errorDescription`,无需感知具体哪个贡献点失败。
public struct LumiPluginContributionFailure: Sendable, Equatable {
    /// 失败插件的唯一标识(`LumiPluginInfo.id`)。
    public let pluginID: String

    /// 失败插件的显示名称(`LumiPluginInfo.displayName`),便于 UI 直接展示。
    public let pluginDisplayName: String

    /// 失败的贡献点标识(如 `"agentTools"`),用于定位是哪个聚合方法抛错。
    public let contribution: String

    /// 失败时的底层错误描述。
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

/// 启动期插件工具加载失败的聚合错误。
///
/// 当所有插件 lifecycle 完成后收集工具,若失败列表非空,
/// 就把失败列表包装成本错误抛出,由启动层走 `CrashedView` 呈现——
/// 启动期插件失败视为需要用户介入的硬条件(区别于运行期插件开关触发的
/// 软失败,后者只走「设置 → 插件」详情页 banner)。
///
/// `localizedDescription` 会列出每个失败插件的显示名与错误描述,便于用户
/// 定位是哪个插件、什么原因。
public struct LumiPluginContributionFailureAggregate: LocalizedError {
    public let failures: [LumiPluginContributionFailure]

    public init(_ failures: [LumiPluginContributionFailure]) {
        self.failures = failures
    }

    public var errorDescription: String? {
        guard !failures.isEmpty else { return "Plugin contribution failures" }
        return "Plugin contribution failures:\n" + failures.map { failure in
            "- \(failure.pluginDisplayName) [\(failure.contribution)]: \(failure.errorDescription)"
        }.joined(separator: "\n")
    }
}
