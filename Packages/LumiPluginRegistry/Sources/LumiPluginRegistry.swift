import ActivityHeatmapPlugin
import AgentDelayMessagePlugin
import AgentRAGPlugin
import AgentRulesPlugin
import AgentTempStoragePlugin
import AgentTurnNotificationPlugin
import AppIconDesignerPlugin
import AppLoadedPluginsPlugin
import AppManagerPlugin
import AppStoreConnectPlugin
import AppUpdateStatusBarPlugin
import AskUserPlugin
import AutoTaskPlugin
import BrewManagerPlugin
import BrowserPlugin
import CADDesignerPlugin
import CaffeinatePlugin
import ChatModePlugin
import ChatPanelPlugin
import ClipboardManagerPlugin
import CodeReviewPlugin
import ConversationLanguagePlugin
import ConversationListPlugin
import ConversationNewPlugin
import ConversationForkPlugin
import ConversationTimelinePlugin
import ConversationTitlePlugin
import DatabaseManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import DocxReadPlugin
import DownloadPlugin
import EditorBreadcrumbNavPlugin
import EditorCallHierarchyPlugin
import EditorFileTreePlugin
import EditorFileTreeV2Plugin
import EditorOutlinePlugin
import EditorPanelPlugin
import EditorPreviewPlugin
import EditorProblemsPlugin
import EditorReferencesPlugin
import EditorSearchPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorSwiftPlugin
import EditorSymbolsPlugin
import EditorTabStripPlugin
import EditorTerminalPlugin
import FileLogPlugin
import FontConfigPlugin
import GitHubPlugin
import GitPlugin
import GoalTaskPlugin
import HistoryDBStatusBarPlugin
import HostsManagerPlugin
import IdleTimePlugin
import InputPlugin
import LayoutPlugin
import LLMProviderAiRouterPlugin
import LLMProviderAliyunPlugin
import LLMProviderAnthropicPlugin
import LLMProviderCodexPlugin
import LLMProviderDeepSeekPlugin
import LLMProviderFeifeimiaoPlugin
import LLMProviderFlyMuxPlugin
import LLMProviderFreeModelPlugin
import LLMProviderHappyCodePlugin
import LLMProviderHyperAPIPlugin
import LLMProviderKimiCodePlugin
import LLMProviderLPgptPlugin
import LLMProviderMiniMaxPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderMLXPlugin
import LLMProviderOpenAIPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderStepFunPlugin
import LLMProviderSublyxPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderZhipuPlugin
import LogoCofficPlugin
import LogoSmartLightPlugin
import LumiCoreKit
import MemoryPlugin
import MenuBarManagerPlugin
import MessageListPlugin
import MessageRendererPlugin
import ModelSelectorPlugin
import NettoPlugin
import NetworkManagerPlugin
import OnboardingPlugin
import OpenInAntigravityPlugin
import OpenInCursorPlugin
import OpenInFinderPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenInXcodePlugin
import OpenRemotePlugin
import PortManagerPlugin
import ProjectIssueScannerPlugin
import ProjectOverviewPlugin
import ProjectsPlugin
import QuickFileSearchPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import RequestLogPlugin
import ShowImagePlugin
import SkillPlugin
import TerminalPlugin
import ThemeAuroraPlugin
import ThemeAutumnPlugin
import ThemeDraculaPlugin
import ThemeGithubPlugin
import ThemeLumiPlugin
import ThemeMidnightPlugin
import ThemeMountainPlugin
import ThemeNebulaPlugin
import ThemeOneDarkPlugin
import ThemeOrchardPlugin
import ThemeRiverPlugin
import ThemeSkyPlugin
import ThemeSpringPlugin
import ThemeStatusBarPlugin
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import ToolCorePlugin
import VerbosityPlugin
import VideoConverterPlugin
import WebFetchPlugin
import WebSearchPlugin
import os
import SuperLogKit

/// 插件注册表
@MainActor
public enum LumiPluginRegistry: SuperLog {
    /// SuperLog 标识 emoji
    public nonisolated static let emoji = "📦"

    /// 是否启用详细日志输出
    public nonisolated static let verbose: Bool = false

    /// 日志记录器
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiPluginRegistry")

    /// 最近一次 lifecycle（registerAll + appDidLaunch）累积的插件失败列表。
    ///
    /// 逐插件捕获 `lifecycle(_:)` 抛出的错误，反映"当前插件集"的最新失败快照。
    /// 由 `RootContainer.bootstrapAfterPluginLifecycle` 读取，启动期失败走 CrashedView。
    private static var _lifecycleFailures: [LumiPluginContributionFailure] = []

    /// 最近一次 lifecycle 失败快照（只读访问）。
    public static var lifecycleFailures: [LumiPluginContributionFailure] {
        _lifecycleFailures
    }

    /// 逐插件触发 lifecycle 事件并捕获失败，累积到 `_lifecycleFailures`。
    ///
    /// 单个插件抛错**不影响其他插件**：异常被捕获并包装成 `LumiPluginContributionFailure`，
    /// 其他插件照常收到事件。与 `agentTools` 的聚合模式一致。
    @MainActor
    private static func dispatchLifecycle(
        _ event: LumiPluginLifecycle,
        verboseLabel: String
    ) async {
        if verbose {
            logger.info("\(Self.t)\(verboseLabel)，共 \(Self.plugins.count) 个插件")
        }
        for plugin in plugins {
            do {
                try await plugin.lifecycle(event)
            } catch {
                _lifecycleFailures.append(LumiPluginContributionFailure(
                    pluginID: plugin.info.id,
                    pluginDisplayName: plugin.info.displayName,
                    contribution: "lifecycle.\(event.label)",
                    errorDescription: error.localizedDescription
                ))
                logger.error("插件 \(plugin.info.id) lifecycle(\(event.label)) 失败：\(error.localizedDescription)")
            }
        }
        if verbose {
            logger.info("\(Self.t)\(verboseLabel) 完成")
        }
    }

    /// 注册所有插件并触发 didRegister 生命周期事件
    public static func registerAll() async {
        _lifecycleFailures = []
        await dispatchLifecycle(.didRegister, verboseLabel: "开始注册所有插件")
    }

    /// 触发应用启动生命周期事件
    public static func appDidLaunch() async {
        await dispatchLifecycle(.appDidLaunch, verboseLabel: "触发 appDidLaunch")
    }

    /// 在 app 启动早期、首帧渲染之前同步触发布局状态恢复。
    ///
    /// 背景：原本 `LayoutPlugin.lifecycle(.appDidLaunch)`（通过 `PluginService.init` 的异步 Task 触发）
    /// 会晚于 `AppLayoutView.onAppear` 执行，导致 `onAppear` 的默认选择先把 `containers[0]` 写入
    /// `activeViewContainerID` 并落盘，覆盖了磁盘里的持久化值。此入口让 restore 提前到
    /// `RootContainer.init` 同步阶段完成，确保首帧渲染前布局状态已是持久化值。
    ///
    /// restore 幂等：后续 `.appDidLaunch` 的二次调用为 no-op（普通属性 didSet 去重、divider 走无副作用的 restoreXxx）。
    @MainActor
    public static func restoreLayoutEarly() {
        if verbose {
            logger.info("\(Self.t)同步恢复布局状态")
        }
        // 此入口在 PluginService.init 阶段同步调用，早于 lumiCore 就绪。lifecycle 现已
        // 改为 throws，但此处失败通常是时序性的（layoutComponent.state 尚未就绪），不是
        // 真失败——故用 try? 降级，不累积到 _lifecycleFailures，避免误报走 CrashedView。
        // 真正的 lifecycle 失败由 registerAll/appDidLaunch 的聚合捕获覆盖。
        try? LayoutPlugin.lifecycle(.appDidLaunch)
    }

    /// 检测所有已注册插件是否有 ID 重复。
    ///
    /// 返回：如果存在重复，返回 [(id: String, plugins: [any LumiPlugin.Type])]；否则返回空数组。
    /// 注意：这是一个调试/开发辅助函数，建议在应用启动时调用一次进行校验。
    public static func detectDuplicatePluginIDs() -> [(id: String, plugins: [any LumiPlugin.Type])] {
        var idToPlugins: [String: [any LumiPlugin.Type]] = [:]

        // 收集所有插件的 ID
        for plugin in plugins {
            let pluginID = plugin.info.id
            idToPlugins[pluginID, default: []].append(plugin)
        }

        // 过滤出重复的 ID
        let duplicates = idToPlugins
            .filter { $0.value.count > 1 }
            .map { (id: $0.key, plugins: $0.value) }
            .sorted { $0.id < $1.id }

        if verbose {
            if duplicates.isEmpty {
                logger.info("\(Self.t)未检测到重复插件 ID")
            } else {
                logger.warning("\(Self.t)检测到重复插件 ID：\(duplicates.map { $0.id }.joined(separator: ", "))")
            }
        }
        return duplicates
    }

    public static let plugins: [any LumiPlugin.Type] =
        themePlugins +
        chatPlugins +
        llmProviderPlugins +
        openInPlugins +
        [
            // MARK: - Core Tools
            TerminalPlugin.self,
            FontConfigPlugin.self,
            AppLoadedPluginsPlugin.self,
            ToolCorePlugin.self,
            MessageRendererPlugin.self,
            MemoryPlugin.self,
            AgentRulesPlugin.self,
            SkillPlugin.self,
            RequestLogPlugin.self,
            HistoryDBStatusBarPlugin.self,
            ActivityHeatmapPlugin.self,
            RAGPlugin.self,
            AgentTempStoragePlugin.self,

            // MARK: - Logo Plugins
            LogoSmartLightPlugin.self,
            LogoCofficPlugin.self,
        ] +
        [
            // MARK: - Others
            VideoConverterPlugin.self,
            DownloadPlugin.self,
            DocxReadPlugin.self,
            PortManagerPlugin.self,
        ] +
        conversationPlugins +
        [LayoutPlugin.self] +
        editorPlugins
}
