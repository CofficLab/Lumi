import BookletMakerPlugin
import KernelLumi
import LogoPlugin
import SettingsPlugin
import StoragePlugin
import ThemeLumiPlugin
import ThemeManagerPlugin
import WorkspacePlugin

/// iOS 版 BookletMaker 精简插件目录。
///
/// 与 macOS 的 16 插件目录不同，iOS 只链接 BookletMaker 核心流程真正需要的
/// 服务（workspace 注册表 / storage 导出目录 / theme 渲染 / settings / logo），
/// 不包含编辑器、LLM、Agent、消息等重型栈。内核以宽松模式启动
///（`requiresAllCoreServices = false`），缺失的服务由各聚合步骤优雅 no-op。
@MainActor
public enum BookletMakerPluginCatalog {
    /// BookletMaker 插件的稳定 ID。
    public static let bookletMakerPluginID = "com.coffic.lumi.plugin.booklet-maker"

    /// iOS 版所需的最小插件集（按依赖安全顺序）。
    static let bookletMakerPlugin = BookletMakerPlugin()

    public static let plugins: [any LumiPlugin] = {
        var list: [any LumiPlugin] = [
            WorkspacePlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            ThemeManagerPlugin(),
            ThemeLumiPlugin(),
            bookletMakerPlugin,
        ]

        // StoragePlugin 需要可抛错的初始化；失败时跳过。
        if let plugin = try? StoragePlugin() {
            list.insert(plugin, at: 0)
        }

        return list
    }()
}
