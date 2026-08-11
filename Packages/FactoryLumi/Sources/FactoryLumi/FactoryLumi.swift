import FactoryCore
import LumiKernel
import SwiftUI

/// FactoryLumi 门面
///
/// 组装 Lumi 的完整插件目录，并把生命周期与 UI 工作委托给 `FactoryCore`。
/// Lumi 直营版本通过 `additionalPlugins` 显式注入 `AppUpdatePlugin` 和
/// `ProjectRAGPlugin`，避免它们被强制链接进其它分发渠道的宿主。
@MainActor
public enum FactoryLumi {
    /// 默认的完整 Lumi 配置。
    public static func configuration(
        additionalPlugins: [any LumiPlugin] = []
    ) -> FactoryConfiguration {
        // 完整目录 + 宿主显式注入的插件。FactoryConfiguration 的 throwing
        // 初始化负责校验 ID 唯一性。这里捕获失败意味着内置目录本身有缺陷，
        // 属于编译期/开发期错误，直接 fatalError 让问题尽早暴露。
        try! FactoryConfiguration(
            plugins: LumiPluginCatalog.plugins + additionalPlugins
        )
    }

    /// 创建主窗口视图。
    public static func makeMainWindow(
        additionalPlugins: [any LumiPlugin] = []
    ) -> some View {
        FactoryCore.makeMainWindow(configuration: configuration(additionalPlugins: additionalPlugins))
    }

    /// 创建设置窗口视图。
    public static func makeSettingsWindow() -> some View {
        FactoryCore.makeSettingsWindow()
    }

    /// 创建应用命令菜单。
    public static func makeCommands() -> some Commands {
        FactoryCore.makeCommands()
    }

    // MARK: - Transitional ID Selection (AppIconDesigner / CADDesigner / DatabaseManager)

    /// :nodoc: 过渡 API——仅供尚未建立专属 Factory 的独立应用使用。
    ///
    /// 按白名单 ID 从完整目录中筛选插件。这是为了在编译期插件组合落地前
    /// 保持这些应用的既有运行时行为；它们仍然会链接完整插件图，**不获得
    /// 体积收益**。新应用应建立自己的 `FactoryXxx` 而不是调用此 API。
    @available(*, deprecated, message: "建立专属 FactoryXxx 编译期插件组合，不要复用完整目录")
    public static func configuration(
        allowingIDs allowlist: Set<String>,
        enabledPluginIDs: Set<String> = [],
        initialContainerID: String? = nil,
        showsStatusBar: Bool = true,
        showsActivityBar: Bool = true
    ) throws -> FactoryConfiguration {
        let registered = Set(LumiPluginCatalog.plugins.map(\.id))
        let unknown = allowlist.subtracting(registered)
        guard unknown.isEmpty else {
            throw FactoryConfigurationError.unknownEnabledPluginIDs(unknown)
        }

        let enabledOutsideAllowlist = enabledPluginIDs.subtracting(allowlist)
        guard enabledOutsideAllowlist.isEmpty else {
            // 复用 unknownEnabledPluginIDs 报错语义：需要启用的插件不在白名单中。
            throw FactoryConfigurationError.unknownEnabledPluginIDs(enabledOutsideAllowlist)
        }

        let plugins = LumiPluginCatalog.plugins.filter { allowlist.contains($0.id) }
        return try FactoryConfiguration(
            plugins: plugins,
            enabledPluginIDs: enabledPluginIDs,
            initialContainerID: initialContainerID,
            showsStatusBar: showsStatusBar,
            showsActivityBar: showsActivityBar
        )
    }
}
