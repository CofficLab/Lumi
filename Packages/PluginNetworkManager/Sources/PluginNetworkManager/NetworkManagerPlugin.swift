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
import KitSuperLog

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
public final class NetworkManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    public let id = "com.coffic.lumi.plugin.network-manager"
    public let order = 30
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.network-manager",
        name: "Network Manager",
        description: "",
        category: .system,
        stage: .stable,
        policy: .enabledByDefault
    )

    public var name: String {
        LumiPluginLocalization.string("Network Monitor", bundle: .module)
    }


    private var httpExchangeStore: HTTPExchangeStore?

    public init() {}

    // MARK: - SuperPlugin

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 初始化 HTTPExchangeStore
        let exchangeStore: HTTPExchangeStore?
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let dir = storage.pluginDataDirectory(for: "NetworkManager")
            exchangeStore = HTTPExchangeStore(directory: dir)
        } else {
            exchangeStore = nil
        }
        httpExchangeStore = exchangeStore
        NetworkService.shared.configureHTTPExchangeStore(exchangeStore)

        // 2. 注册 NetworkProviding 到内核（替换默认实现，附带 exchangeStore）
        // 先注销默认的 NetworkProviding，再注册自定义实现
        kernel.unregisterProvider((any NetworkProviding).self)
        let networkProvider: any NetworkProviding
        if let exchangeStore {
            let customProvider = NetworkProvider(exchangeStore: exchangeStore)
            try kernel.registerProvider((any NetworkProviding).self, customProvider)
            networkProvider = customProvider
        } else {
            networkProvider = DefaultNetworkProviding()
        }

        // 2.5 注册 LLMNetworkProviding 适配器（桥接 NetworkProviding → LLMNetworkProviding）
        // 使 LLM 供应商的网络请求经过 kernel 的 NetworkProviding，获得 HTTP 交换记录等能力
        let llmNetworkAdapter = LLMNetworkProviderAdapter(networkProvider)
        try kernel.registerProvider((any LLMNetworkProviding).self, llmNetworkAdapter)

        // 3. 注册 Agent 工具到 ToolManagerProviding
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        // 4. 注册 MenuBar 内容项和弹窗项
        if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
            menuBar.addContent(MenuBarContentItem(
                id: "\(id).speed",
                title: LumiPluginLocalization.string("Network Speed", bundle: .module),
                order: order
            ) {
                NetworkMenuBarContentView()
            })
            menuBar.addPopup(MenuBarPopupItem(
                id: "\(id).popup",
                title: LumiPluginLocalization.string("Network Monitor", bundle: .module),
                order: order
            ) {
                NetworkMenuBarPopupView()
            })
        }

        // 5. 注册设置入口
        if let settingView = kernel.resolveProvider((any SettingViewProviding).self),
           let httpExchangeStore {
            settingView.addEntries([
                SettingEntryItem(
                    id: "\(id).settings",
                    title: LumiPluginLocalization.string("HTTP Logs", bundle: .module),
                    systemImage: "arrow.up.arrow.down.circle",
                    order: order
                ) {
                    HTTPExchangeSettingsView(store: httpExchangeStore)
                },
            ])
        }

        // 6. 注册文档入口（关于）
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { NetworkManagerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { NetworkManagerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回 Agent 工具
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }

        // 撤回 MenuBar 项
        kernel.resolveProvider((any MenuBarProviding).self)?
            .removeItems(ids: ["\(id).speed", "\(id).popup"])

        // 撤回设置入口
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])

        // 撤回文档入口
        kernel.resolveProvider((any DocsViewProviding).self)?
            .removeEntries(id: id)
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
