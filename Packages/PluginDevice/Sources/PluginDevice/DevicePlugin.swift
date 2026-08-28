import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import ProviderWorkspace
import SwiftUI
import KitSuperLog
import os

/// 设备信息插件。
@MainActor
public final class DevicePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.device-info", category: "Device")
    public let id = "com.coffic.lumi.plugin.device-info"
    public let order = 6
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.device-info",
        name: "Device",
        description: "",
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "设备信息") { DeviceInfoAboutView() })
            docs.addManual(DocsEntry(id: id, name: "设备信息") { DeviceInfoManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 0. 配置 MemoryHistoryService 存储目录
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
        }

        // 1. 设置视图入口
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            let entry = SettingEntryItem(
                id: "\(id).memory-settings",
                title: LumiPluginLocalization.string("Memory Monitor", bundle: .module),
                systemImage: "memorychip",
                order: order
            ) {
                MemorySettingsView()
            }
            settings.addEntries([entry])
        }

        // 2. 注册 ActivityBar 入口；入口被激活时由插件切换自己的主内容，
        //    并隐藏侧边栏 Rail（本插件不贡献 Rail 内容，直接全屏展示主视图）。
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: "设备信息",
                    systemImage: "gauge.with.dots.needle.50percent",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    if activeItemID == entryID {
                        // 本插件被激活：展示主内容并隐藏侧边栏 Rail（全屏展示）。
                        contentView?.setContentView(AnyView(DeviceInfoView()))
                        workspace?.setRailVisible(false)
                    } else {
                        // 切换到其它入口时恢复 Rail 可见性。
                        workspace?.setRailVisible(true)
                    }
                },
            ])
        } else {
            // 无 ActivityBar 的精简宿主仍可直接展示插件主内容。
            contentView?.setContentView(AnyView(DeviceInfoView()))
        }

        // 3. 贡献菜单栏内容与弹窗（沿用旧版 menuBarContentItems / menuBarPopupItems）
        if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
            menuBar.addContent(MenuBarContentItem(id: "\(id).metrics", title: "设备信息", order: order) {
                DeviceInfoMenuBarContentView()
            })
            menuBar.addPopup(MenuBarPopupItem(id: "\(id).cpu", title: "CPU", order: order) {
                DeviceInfoMenuBarPopupView()
            })
            menuBar.addPopup(MenuBarPopupItem(id: "\(id).memory", title: "内存", order: order) {
                MemoryMenuBarPopupView()
            })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).memory-settings"])
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        // 恢复 Rail 可见性（本插件激活时可能已将其隐藏）。
        kernel.resolveProvider((any WorkspaceProviding).self)?.setRailVisible(true)
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
        kernel.resolveProvider((any MenuBarProviding).self)?.removeItems(ids: [
            "\(id).metrics",
            "\(id).cpu",
            "\(id).memory",
        ])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
