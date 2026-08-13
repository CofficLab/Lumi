import AgentTurnRunnerPlugin
import BookletMakerPlugin
import CommandPlugin
import EditorKernelPlugin
import EditorProviderPlugin
import LLMProviderManagerPlugin
import KernelLumi
import LogoPlugin
import MessageRendererPlugin
import MessageSenderPlugin
import ProjectsPlugin
import SettingsPlugin
import StoragePlugin
import ThemeLumiPlugin
import ThemeManagerPlugin
import ToolManagerPlugin
import WorkspacePlugin

/// BookletMaker 最小插件目录
///
/// 仅包含 BookletMaker 运行所需的 16 个插件，按依赖安全顺序构造。
/// 与 FactoryLumi 的完整目录相比，这里**不包含**任何 LLM Provider
/// （除管理器外）、数据库插件、MLX、主题全集等，因此编译产物不会
/// 链接这些依赖。
///
/// 顺序遵循与 LumiPluginCatalog 一致的 bootstrap 约束：
/// LLMProviderManager → EditorKernel → EditorProvider 先注册。
@MainActor
public enum BookletMakerPluginCatalog {
    /// BookletMaker 插件的稳定 ID。
    public static let bookletMakerPluginID = "com.coffic.lumi.plugin.booklet-maker"

    /// BookletMaker 所需的 16 个插件（按依赖安全顺序）。
    public static let plugins: [any LumiPlugin] = {
        var list: [any LumiPlugin] = [
            // 核心服务：必须先于依赖它们的插件注册。
            LLMProviderManagerPlugin(),
            // EditorKernelPlugin 必须先于 EditorProviderPlugin:
            // 前者在 OnBoot 注册具象 EditorService,后者在 OnReady resolve 并转发文件操作。
            EditorKernelPlugin(),
            EditorProviderPlugin(),
            ToolManagerPlugin(),
            ProjectsPlugin(),
            WorkspacePlugin(),
            MessageSenderPlugin(),
            AgentTurnRunnerPlugin(),
            MessageRendererPlugin(),
            CommandPlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            ThemeManagerPlugin(),
            ThemeLumiPlugin(),
            BookletMakerPlugin(),
        ]

        // StoragePlugin 需要可抛错的初始化；失败时跳过（与 LumiPluginCatalog 行为一致）。
        if let plugin = try? StoragePlugin() {
            list.append(plugin)
        }

        return list
    }()
}
