import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import ProviderWorkspace
import SwiftUI

/// 设备信息插件
/// - 注册设备信息视图为主内容（ContentView）；
/// - 贡献菜单栏内容（CPU/内存柱状图）与弹窗（CPU、内存两个独立弹窗项）；
/// - 贡献设置入口（内存监控设置页）；
/// - 贡献「关于」与「说明书」文档；
/// - 配置 MemoryHistoryService 的存储目录。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的各 Provider，
/// 用追加语义注册，不覆盖其他插件的贡献。
@MainActor
public final class DevicePlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.device-info"
    public let order = 6

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 0. 配置 MemoryHistoryService 存储目录（沿用旧版语义）
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
        }

        // 1. 设置视图入口（内存监控设置页，沿用旧版 settingsTabItems）
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            let entry = SettingEntryItem(
                id: "\(id).memory-settings",
                title: "Memory Monitor",
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

        // 3. 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "设备信息") { DeviceInfoAboutView() })
            docs.addManual(DocsEntry(id: id, name: "设备信息") { DeviceInfoManualView() })
        }

        // 4. 贡献菜单栏内容与弹窗（沿用旧版 menuBarContentItems / menuBarPopupItems）
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
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any MenuBarProviding).self)?.removeItems(ids: [
            "\(id).metrics",
            "\(id).cpu",
            "\(id).memory",
        ])
    }
}
