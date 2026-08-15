import KernelCore
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import SwiftUI

/// 设备信息插件
///
/// 完美复刻自 Lumi 旧版 `DeviceInfoPlugin`（KernelLumi → KernelCore 适配）：
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

        // 2. 注册设备信息视图为主内容（ContentView，沿用旧版 viewContainers）
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            contentView.setContentView(AnyView(DeviceInfoView()))
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
}
