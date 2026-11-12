import KernelCore
import LumiLoggingKit
import os
import ProviderActivityBar
import ProviderToolbar
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderMessage
import ProviderMessageRendering
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderToolManager
import SwiftUI

/// 设备信息插件。
@MainActor
public final class DevicePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.device-info", category: "Device")
    public let id = "com.coffic.lumi.plugin.device-info"
    public let order = 6
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.device-info",
        name: pluginLocalization.string("Device"),
        description: pluginLocalization.string("View device information and hardware status."),
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    private var viewModels: DevicePluginViewModels?
    private var metricsObserver: DeviceMetricsObserver?

    /// 插入设备状态卡片消息的桥。
    ///
    /// 做成插件的实例状态而非全局单例：多个内核并存时（测试进程里并排跑几个
    /// 内核就是这种情况）不会互相抢走消息管理器。
    private let messageBridge = DeviceStatusMessageBridge()

    /// 设备状态采集器。
    private let collector = DeviceStatusCollector()

    /// 当前是否已注册工具与渲染器。
    ///
    /// 用于让 `onEnable` 幂等：内核在「曾经 Boot 过再启用」时只调 `onEnable`，
    /// 而「启动时被跳过、首次启用」时会走完整的 `onBoot`。
    private var isChatRegistered = false

    /// 入口标题的本地化解析；测试可注入替身断言注册链不再写死字面量。
    private let localize: (String) -> String

    public init() {
        self.localize = { pluginLocalization.string($0) }
    }

    init(localize: @escaping (String) -> String) {
        self.localize = localize
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: localize("Device Info")) { DeviceInfoAboutView() })
            docs.addManual(DocsEntry(id: id, name: localize("Device Info")) { DeviceInfoManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let viewModels = DevicePluginViewModels()
        self.viewModels = viewModels
        metricsObserver?.cancel()
        metricsObserver = DeviceMetricsObserver(viewModels: viewModels)

        // 0. 配置历史服务的存储目录
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
            ThermalHistoryService.configure(storageDirectory: pluginStorageDir)
        }

        // 1. 注册 ActivityBar 入口；入口被激活时由插件切换自己的主内容，
        //    并隐藏侧边栏 Rail（本插件不贡献 Rail 内容，直接全屏展示主视图）。
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: localize("Device Info"),
                    systemImage: "gauge.with.dots.needle.50percent",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        // 本插件被激活：展示主内容并隐藏侧边栏 Rail（全屏展示）。
                        contentView?.setContentView(AnyView(DeviceInfoView(viewModels: viewModels)))
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        // 切换到其它入口时恢复 Rail 可见性。
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            // 无 ActivityBar 的精简宿主仍可直接展示插件主内容。
            contentView?.setContentView(AnyView(DeviceInfoView(viewModels: viewModels)))
        }

        try contributeMenuBar(to: kernel, viewModels: viewModels)
        registerChatContributions(kernel: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let viewModels else { return }
        try contributeMenuBar(to: kernel, viewModels: viewModels)
        registerChatContributions(kernel: kernel)
    }

    /// 运行时禁用：撤回工具与渲染器。
    ///
    /// - Important: 内核在运行时禁用插件时只撤回它**显式登记**的贡献
    ///   （`trackContribution`），不会替插件清理 Provider 侧的写入。
    ///   因此工具与渲染器必须由本插件自己在 `onDisable` 里撤回，
    ///   否则插件在设置里显示「已禁用」后，LLM 仍能调用该工具、卡片也仍会渲染。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterChatContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterChatContributions(kernel: kernel)
        metricsObserver?.cancel()
        metricsObserver = nil
        viewModels = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        // 恢复 Rail 可见性（本插件激活时可能已将其隐藏）。
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        rootView?.setRailView(railView?.makeRailView())
        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        rootView?.setContentHeaderViewHidden(false)
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    private func contributeMenuBar(
        to kernel: KernelCoreContainer,
        viewModels: DevicePluginViewModels
    ) throws {
        guard let menuBar = kernel.resolveProvider((any MenuBarProviding).self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addContent(MenuBarContribution(
            id: "\(id).metrics",
            title: localize("Device Info"),
            order: order,
            ownerPluginID: id
        ) {
            DeviceInfoMenuBarContentView(viewModel: viewModels.menuBar)
        })
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).cpu",
            title: "CPU",
            order: order,
            ownerPluginID: id
        ) {
            DeviceInfoMenuBarPopupView(
                viewModel: viewModels.cpu,
                thermalViewModel: viewModels.thermal,
                historyViewModel: viewModels.cpuHistory,
                thermalHistoryViewModel: viewModels.thermalHistory
            )
        })
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).memory",
            title: localize("Memory"),
            order: order,
            ownerPluginID: id
        ) {
            MemoryMenuBarPopupView(viewModel: viewModels.memory, historyViewModel: viewModels.memoryHistory)
        })
    }

    // MARK: - Chat Contributions

    /// 设备状态卡片渲染器的优先级。
    ///
    /// 必须高于核心渲染器的 `core-system-message`（base + 150 = 160）：
    /// 卡片消息是 `role = .system`，若优先级低于它就会被通用系统消息渲染器接管，
    /// 用户看到的是一行纯文本而不是卡片。
    ///
    /// 取 190 而非 200，是为了与同样用 200 的 Finder / HTMLCanvas / DiskSpeed
    /// 卡片渲染器错开，避免顺序相同的渲染器之间出现不确定的命中顺序。
    static let cardRendererOrder = 190

    /// 登记工具、渲染器与消息桥。
    ///
    /// 幂等：重复调用不会重复注册。
    private func registerChatContributions(kernel: KernelCoreContainer) {
        guard !isChatRegistered else { return }
        isChatRegistered = true

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            toolManager.add(
                DeviceStatusTool(bridge: messageBridge, collector: collector),
                pluginID: id
            )
        } else {
            Self.logger.error("\(Self.t)ToolManagerProviding not found; device status tool skipped")
        }

        // 注册卡片渲染器。order 由插件 order 派生，确保卡片消息不被通用渲染器接管。
        if let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) {
            rendering.register(DeviceStatusCardRenderer.item(order: Self.cardRendererOrder))
            Self.logger.info("\(Self.t)Registered device status card renderer")
        } else {
            Self.logger.warning("\(Self.t)MessageRenderingProviding not found; card renderer skipped")
        }

        messageBridge.configure(
            messages: kernel.resolveProvider((any MessageManaging).self)
        )
    }

    /// 撤回工具、渲染器与消息桥。
    private func unregisterChatContributions(kernel: KernelCoreContainer) {
        guard isChatRegistered else { return }
        isChatRegistered = false

        kernel.resolveProvider((any MessageRenderingProviding).self)?
            .unregister(id: DeviceStatusTimeline.rendererID)
        messageBridge.reset()

        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: DeviceStatusTool.toolName)
    }
}
