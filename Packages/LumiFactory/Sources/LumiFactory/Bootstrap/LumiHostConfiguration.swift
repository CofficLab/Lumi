import Foundation

/// 描述一个使用 `LumiFactory` 的宿主应用应加载哪些插件。
///
/// `pluginAllowlist == nil` 保持 Lumi 的现有行为：注册全部内置插件。
/// 传入集合时只注册集合中明确列出的插件，不会自动补齐依赖。
public struct LumiHostConfiguration: Sendable {
    public let pluginAllowlist: Set<String>?
    public let enabledPluginIDs: Set<String>
    public let initialContainerID: String?
    public let showsStatusBar: Bool
    public let showsActivityBar: Bool

    public init(
        pluginAllowlist: Set<String>? = nil,
        enabledPluginIDs: Set<String> = [],
        initialContainerID: String? = nil,
        showsStatusBar: Bool = true,
        showsActivityBar: Bool = true
    ) {
        self.pluginAllowlist = pluginAllowlist
        self.enabledPluginIDs = enabledPluginIDs
        self.initialContainerID = initialContainerID
        self.showsStatusBar = showsStatusBar
        self.showsActivityBar = showsActivityBar
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
