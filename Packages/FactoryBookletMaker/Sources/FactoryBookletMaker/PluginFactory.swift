import KernelCore
import BookletMakerPlugin

#if os(macOS)
import PluginActivityBar
import PluginCommand
import PluginLogoCoffic
import PluginLogoManager
import PluginSettingView
import PluginStorage
import PluginThemePack
#endif

/// BookletMaker 的专用插件目录。
///
/// 只装配 BookletMaker 工作流和宿主 UI 所需的基础插件。Lumi 的 LLM、Agent、
/// 项目、聊天、开发工具和其他实验性插件不会进入这个应用的进程。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        #if os(iOS)
        return [BookletMakerPlugin(policy: .required)]
        #else
        [
            // 基础服务必须先于业务插件启动。
            try! StorageSuperPlugin(),
            CommandPlugin(),
            PluginSettingView(),
            PluginLogoManager(),
            PluginActivityBar(),
            LogoCofficPlugin(),
            ThemePackPlugin(),
            // BookletMaker 是此宿主的核心能力，不能被用户关闭。
            BookletMakerPlugin(policy: .required),
        ]
        #endif
    }
}

/// 在专用宿主需要时，按显式 allow-list 选择插件。
@MainActor
public struct SelectedPluginFactory: PluginFactory {
    private let base: any PluginFactory
    public let allowedPluginIDs: Set<String>

    public init(allowedPluginIDs: Set<String>) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = DefaultPluginFactory()
    }

    public init(allowedPluginIDs: Set<String>, base: any PluginFactory) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = base
    }

    public func makePlugins() -> [any SuperPlugin] {
        base.makePlugins().filter { allowedPluginIDs.contains($0.id) }
    }
}
