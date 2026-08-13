import Foundation
import KernelLumi

/// 描述一个使用 `FactoryCore` 的宿主应用应加载哪些插件。
///
/// 与旧 `LumiHostConfiguration` 的关键差异：**插件列表由宿主 Factory 在
/// 编译期确定并显式传入**，Core 不再维护内置插件注册表，也不再按 ID 过滤。
/// 这让每个应用 Target 只链接自己需要的插件包，编译器能裁掉其余插件依赖。
///
/// `enabledPluginIDs` 表示宿主希望**默认启用**（覆盖用户持久化的 opt-in 插件）。
/// 它必须是 `plugins.map(\.id)` 的子集，否则视为配置错误。
public struct FactoryConfiguration: @unchecked Sendable {
    /// 宿主在编译期确定的最终插件列表，按依赖安全顺序排列。
    ///
    /// 之所以用 `@unchecked Sendable`：`LumiPlugin` 是 `@MainActor` 的
    /// class-only 协议，本身不满足 `Sendable`。但这些实例只会从
    /// `@MainActor` 上下文构造并传入，且仅在 `@MainActor` 的
    /// `createKernel` 中被消费，跨 actor 传递期间不存在并发访问，
    /// 因此手动声明 `Sendable` 是安全的。
    public let plugins: [any LumiPlugin]

    /// 宿主希望默认启用的 opt-in 插件 ID（`plugins.map(\.id)` 的子集）。
    public let enabledPluginIDs: Set<String>

    /// 启动后激活的视图容器 ID（可选）。
    public let initialContainerID: String?

    /// 是否显示状态栏。
    public let showsStatusBar: Bool

    /// 是否显示活动栏。
    public let showsActivityBar: Bool

    /// 创建并校验一份宿主配置。
    ///
    /// 标为 `@MainActor` 是因为校验需要读取 `LumiPlugin.id`（插件协议本身是
    /// `@MainActor`）。所有真实调用方（App 入口、宿主 Factory 门面）都运行在
    /// 主线程，因此这个约束不增加实际负担。
    ///
    /// - Parameters:
    ///   - plugins: 最终插件列表（顺序敏感）。
    ///   - enabledPluginIDs: 希望默认启用的插件 ID，必须是 `plugins` 的子集。
    ///   - initialContainerID: 启动后激活的视图容器 ID。
    ///   - showsStatusBar: 是否显示状态栏。
    ///   - showsActivityBar: 是否显示活动栏。
    /// - Throws: `FactoryConfigurationError`——重复插件 ID、或 `enabledPluginIDs`
    ///   含未知 ID。
    @MainActor
    public init(
        plugins: [any LumiPlugin],
        enabledPluginIDs: Set<String> = [],
        initialContainerID: String? = nil,
        showsStatusBar: Bool = true,
        showsActivityBar: Bool = true
    ) throws {
        var seenIDs = Set<String>()
        for plugin in plugins {
            guard seenIDs.insert(plugin.id).inserted else {
                throw FactoryConfigurationError.duplicatePluginID(plugin.id)
            }
        }

        let unknownEnabled = enabledPluginIDs.subtracting(seenIDs)
        guard unknownEnabled.isEmpty else {
            throw FactoryConfigurationError.unknownEnabledPluginIDs(unknownEnabled)
        }

        self.plugins = plugins
        self.enabledPluginIDs = enabledPluginIDs
        self.initialContainerID = initialContainerID
        self.showsStatusBar = showsStatusBar
        self.showsActivityBar = showsActivityBar
    }
}

public enum FactoryConfigurationError: LocalizedError {
    case duplicatePluginID(String)
    case unknownEnabledPluginIDs(Set<String>)
    case unknownInitialContainerID(String)

    public var errorDescription: String? {
        switch self {
        case let .duplicatePluginID(id):
            return "插件列表包含重复的插件 ID：\(id)"
        case let .unknownEnabledPluginIDs(ids):
            return "需要启用的插件不在插件列表中：\(ids.sorted().joined(separator: ", "))"
        case let .unknownInitialContainerID(id):
            return "初始视图容器未注册：\(id)"
        }
    }
}
