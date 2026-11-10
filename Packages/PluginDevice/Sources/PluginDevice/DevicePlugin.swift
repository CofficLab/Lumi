import KernelCore
import LumiLoggingKit
import os
import ProviderActivityBar
import ProviderToolbar
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
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
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let viewModels else { return }
        try contributeMenuBar(to: kernel, viewModels: viewModels)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
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
}
