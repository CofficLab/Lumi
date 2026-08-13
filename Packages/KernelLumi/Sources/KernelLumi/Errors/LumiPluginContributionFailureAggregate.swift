import Foundation

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
