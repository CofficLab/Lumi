import Foundation
import LumiKernel

/// 描述一个使用 `LumiFactory` 的宿主应用应加载哪些插件。
///
/// `pluginAllowlist == nil` 保持 Lumi 的现有行为：注册全部内置插件。
/// 传入集合时只注册集合中明确列出的插件，不会自动补齐依赖。
///
/// `additionalPlugins` 让宿主可以在内置插件之外**显式注入**少数插件。
/// 这是从分发渠道敏感的依赖（例如 `AppUpdatePlugin` → Sparkle）中解耦
/// `LumiFactory` 的关键：这类插件不再由 `LumiFactory` 静态引用，而由
/// 真正需要它的宿主（如直营分发的 Lumi）注入，从而让其它宿主
/// （如上架 Mac App Store 的独立 app）的二进制中不包含 Sparkle。
/// `additionalPlugins` 绕过白名单校验，原样追加到最终插件列表。
public struct LumiHostConfiguration: @unchecked Sendable {
    public let pluginAllowlist: Set<String>?
    public let enabledPluginIDs: Set<String>
    public let initialContainerID: String?
    public let showsStatusBar: Bool
    public let showsActivityBar: Bool

    /// 宿主显式注入、绕过内置白名单的插件。
    ///
    /// 之所以用 `@unchecked Sendable`：`LumiPlugin` 是 `@MainActor` 的
    /// class-only 协议，本身不满足 `Sendable`。但这些实例只会从
    /// `@MainActor` 上下文构造并传入，且仅在 `@MainActor` 的
    /// `createKernel` 中被消费，跨 actor 传递期间不存在并发访问，
    /// 因此手动声明 `Sendable` 是安全的。
    public let additionalPlugins: [any LumiPlugin]

    public init(
        pluginAllowlist: Set<String>? = nil,
        enabledPluginIDs: Set<String> = [],
        initialContainerID: String? = nil,
        showsStatusBar: Bool = true,
        showsActivityBar: Bool = true,
        additionalPlugins: [any LumiPlugin] = []
    ) {
        self.pluginAllowlist = pluginAllowlist
        self.enabledPluginIDs = enabledPluginIDs
        self.initialContainerID = initialContainerID
        self.showsStatusBar = showsStatusBar
        self.showsActivityBar = showsActivityBar
        self.additionalPlugins = additionalPlugins
    }

    /// Lumi 主应用的默认配置。
    public static let lumi = LumiHostConfiguration()
}

public enum LumiHostConfigurationError: LocalizedError {
    case unknownPluginIDs(Set<String>)
    case enabledPluginsOutsideAllowlist(Set<String>)
    case unknownInitialContainerID(String)

    public var errorDescription: String? {
        switch self {
        case let .unknownPluginIDs(ids):
            return "插件白名单包含未注册的插件：\(ids.sorted().joined(separator: ", "))"
        case let .enabledPluginsOutsideAllowlist(ids):
            return "需要启用的插件不在白名单中：\(ids.sorted().joined(separator: ", "))"
        case let .unknownInitialContainerID(id):
            return "初始视图容器未注册：\(id)"
        }
    }
}
