import KernelCore
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import SwiftUI

/// 设备信息插件
///
/// 在设置视图中注册「设备信息」入口，详情展示设备静态信息与动态指标
/// （CPU / 内存 / 磁盘 / 电池 / 运行时间）；并把设备信息视图注册为
/// 当前主内容视图（ContentView）；同时贡献「关于」与「说明书」文档。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的各 Provider，
/// 用追加语义注册，不覆盖其他插件的贡献。
@MainActor
public final class DevicePlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.device"
    public let order = 150

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 设置视图入口（详情展示设备信息）
        if let settings = kernel.resolveProvider((any SettingViewProviding).self) {
            let entry = SettingEntryItem(
                id: "device",
                title: "设备信息",
                systemImage: "macbook.and.iphone",
                order: 150
            ) {
                DeviceInfoView()
            }
            settings.addEntries([entry])
        }

        // 2. 注册设备信息视图为主内容（ContentView）
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            contentView.setContentView(AnyView(DeviceInfoView()))
        }

        // 3. 贡献「关于」与「说明书」文档
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "设备信息") { DeviceInfoAboutView() })
            docs.addManual(DocsEntry(id: id, name: "设备信息") { DeviceInfoManualView() })
        }

        // 4. 贡献菜单栏内容与弹窗
        if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
            menuBar.addContent(MenuBarContentItem(id: "\(id).content", title: "设备信息") {
                DeviceMenuBarContentView()
            })
            menuBar.addPopup(MenuBarPopupItem(id: "\(id).popup", title: "设备信息") {
                DeviceMenuBarPopupView()
            })
        }
    }
}
