import KernelCore
import ProviderContentView
import ProviderSettingView
import SwiftUI

/// 设备信息插件
///
/// 在设置视图中注册「设备信息」入口，详情展示设备静态信息与动态指标
/// （CPU / 内存 / 磁盘 / 电池 / 运行时间）；并把设备信息视图注册为
/// 当前主内容视图（ContentView）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`
/// 与 `ContentViewProviding`，用追加语义注册，不覆盖其他插件的贡献。
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
    }
}
