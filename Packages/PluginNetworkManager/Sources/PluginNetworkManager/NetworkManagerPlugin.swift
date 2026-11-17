import KitAgentTool
import KernelCore
import KitLLM
import os
import ProviderDocsView
import ProviderMenuBar
import ProviderNetwork
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import SwiftUI
import LumiLoggingKit
/// Network Manager 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/NetworkManagerPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 参考 `PluginDiskManager` 的装配方式：
/// - `onBoot` 注册 Agent 工具、MenuBar 菜单栏内容/弹窗、设置入口、文档入口；
/// - `onShutdown` 全部撤回。
///
/// 与旧版的对应关系：
/// - `agentTools` → `ToolManagerProviding`（7 个工具，`LumiAgentTool` → `SuperAgentTool`）；
/// - `menuBarContentItems` / `menuBarPopupItems` → `MenuBarProviding.addContent` / `addPopup`；
/// - `settingsTabItems` → `SettingViewProviding.addEntries`；
/// - `pluginAboutView` → `DocsViewProviding.addAbout`；
/// - `statusBarItems` → 暂不复刻（新版无 StatusBarProviding）。
@MainActor
public final class NetworkManagerPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    public let id = "com.coffic.lumi.plugin.network-manager"
    public let legacyDataDirectoryNames = ["NetworkManager"]
    public let order = 30
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.network-manager",
        name: pluginLocalization.string("Network Manager"),
        description: pluginLocalization.string("Monitor upload/download speed, traffic statistics, and process usage in real time; view network status from the menu bar."),
        category: .system,
        stage: .stable,
        policy: .enabledByDefault
    )

    public var name: String {
        pluginLocalization.string("Network Monitor")
    }

    private var httpExchangeStore: HTTPExchangeStore?
    private var httpExchangeObserver: HTTPExchangeObserver?
    private var httpExchangeSettingsState: HTTPExchangeSettingsState?
    private var viewModels: NetworkPluginViewModels?
    private var metricsObserver: NetworkMetricsObserver?

    public init() {}

    public func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // 旧版网络历史曾写入未版本化的 Lumi/NetworkManager 目录。
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let legacyDirectory = appSupport?.appendingPathComponent("Lumi/NetworkManager", isDirectory: true)
        guard let legacyDirectory,
              FileManager.default.fileExists(atPath: legacyDirectory.path) else { return }

        try FileManager.default.createDirectory(
            at: context.currentPluginDataDirectory,
            withIntermediateDirectories: true
        )
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: legacyDirectory,
            to: context.currentPluginDataDirectory
        )
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { NetworkManagerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { NetworkManagerManualView() })
        }
    }

    // MARK: - SuperPlugin

    public func onBoot(kernel: KernelCoreContainer) throws {
        let viewModels = NetworkPluginViewModels()
        self.viewModels = viewModels
        // 1. 初始化 HTTPExchangeStore。store / settingsState / viewModels 在
        //    「禁用 → 启用」周期内复用，不随运行时禁用销毁。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            httpExchangeStore = HTTPExchangeStore(directory: storage.pluginDataDirectory(for: id))
        } else {
            httpExchangeStore = nil
        }
        httpExchangeSettingsState = httpExchangeStore == nil ? nil : HTTPExchangeSettingsState()

        // 2. 注册 NetworkProviding / LLMNetworkProviding。内核运行时禁用会保留
        //    Provider 注册（兼容 Boot/Enable 分层），故只在 Boot 装配一次。
        kernel.unregisterProvider((any NetworkProviding).self)
        let networkProvider: any NetworkProviding
        if let exchangeStore = httpExchangeStore {
            let customProvider = NetworkProvider(exchangeStore: exchangeStore)
            try kernel.registerProvider((any NetworkProviding).self, customProvider)
            networkProvider = customProvider
        } else {
            networkProvider = DefaultNetworkProviding()
        }
        // 桥接 NetworkProviding → LLMNetworkProviding，使 LLM 供应商的网络请求
        // 经过 kernel 的 NetworkProviding，获得 HTTP 交换记录等能力。
        try kernel.registerProvider((any LLMNetworkProviding).self, LLMNetworkProviderAdapter(networkProvider))

        try installRuntimeContributions(kernel: kernel, viewModels: viewModels)
    }

    /// 运行时重新启用：恢复采样、工具、菜单栏与设置入口。
    ///
    /// Provider 仍保持注册，这里只重建被 `onDisable` 停掉的运行时资源。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let viewModels else { return }
        try installRuntimeContributions(kernel: kernel, viewModels: viewModels)
    }

    /// 运行时禁用：停止监控并撤回工具与设置入口。
    ///
    /// 内核运行时禁用只撤回经 `trackContribution` 显式登记的贡献（菜单栏），
    /// 不会停掉插件自有的采样/定时器/历史写入，也不会清理直接写进
    /// `ToolManagerProviding` / `SettingViewProviding` 的工具与设置入口。
    /// 若不在这里自行停止，插件显示「已禁用」后网络采样、定时刷新、历史录制
    /// 与 7 个 Agent 工具仍在运行、仍可被 LLM 调用（#449）。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeRuntimeContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        removeRuntimeContributions(kernel: kernel)
        viewModels = nil
        httpExchangeSettingsState = nil
        httpExchangeStore = nil
    }

    /// 装配运行时资源与共享贡献：HTTP 交换观察器、历史/交换存储配置、采样
    /// 观察器、Agent 工具、菜单栏与设置入口。Boot 与 Enable 共用，确保两条
    /// 路径恢复出完全一致的运行时状态。
    private func installRuntimeContributions(
        kernel: KernelCoreContainer,
        viewModels: NetworkPluginViewModels
    ) throws {
        if let exchangeStore = httpExchangeStore {
            let settingsState = httpExchangeSettingsState ?? HTTPExchangeSettingsState()
            httpExchangeSettingsState = settingsState
            httpExchangeObserver?.cancel()
            httpExchangeObserver = HTTPExchangeObserver(store: exchangeStore) { [weak settingsState] in
                Task { @MainActor in
                    settingsState?.refresh()
                }
            }
        }
        NetworkHistoryService.shared.configure(storageDirectory: httpExchangeStore?.directory)
        NetworkService.shared.configureHTTPExchangeStore(httpExchangeStore)
        metricsObserver?.cancel()
        metricsObserver = NetworkMetricsObserver(viewModels: viewModels)

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        try contributeMenuBar(to: kernel, viewModels: viewModels)

        if let settingView = kernel.resolveProvider((any SettingViewProviding).self),
           let httpExchangeStore {
            settingView.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: pluginLocalization.string("HTTP Logs"),
                    systemImage: "arrow.up.arrow.down.circle",
                    order: order
                ) {
                    HTTPExchangeSettingsView(
                        store: httpExchangeStore,
                        state: self.httpExchangeSettingsState ?? HTTPExchangeSettingsState()
                    )
                },
            ])
        }
    }

    /// 撤回运行时资源与共享贡献：停采样/定时器、撤工具与设置入口、停 HTTP
    /// 交换观察器、落盘历史并清空共享交换存储。Disable 与 Shutdown 共用。
    /// 菜单栏由内核的贡献撤回机制处理，这里不重复移除。
    private func removeRuntimeContributions(kernel: KernelCoreContainer) {
        metricsObserver?.cancel()
        metricsObserver = nil
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        httpExchangeObserver?.cancel()
        httpExchangeObserver = nil
        NetworkHistoryService.shared.stopRecording()
        NetworkService.shared.configureHTTPExchangeStore(nil)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    private func contributeMenuBar(
        to kernel: KernelCoreContainer,
        viewModels: NetworkPluginViewModels
    ) throws {
        guard let menuBar = kernel.resolveProvider((any MenuBarProviding).self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addContent(MenuBarContribution(
            id: "\(id).speed",
            title: pluginLocalization.string("Network Speed"),
            order: order,
            ownerPluginID: id
        ) {
            NetworkMenuBarContentView(viewModel: viewModels.network)
        })
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).popup",
            title: pluginLocalization.string("Network Monitor"),
            order: order,
            ownerPluginID: id
        ) {
            NetworkMenuBarPopupView(viewModel: viewModels.network, historyViewModel: viewModels.history)
        })
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 NetworkManagerPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListHTTPExchangesTool(),
        GetHTTPSummaryTool(),
        GetHTTPExchangeDetailTool(),
        GetHTTPSlowRequestsTool(),
        GetHTTPFailedRequestsTool(),
        GetHTTPDomainLogTool(),
        DownloadFileTool(),
    ]
}
