import KernelCore
import ProviderSettingView
import SwiftUI

/// 设备信息插件
///
/// 在设置视图中注册「设备信息」入口，详情展示设备静态信息与动态指标
/// （CPU / 内存 / 磁盘 / 电池 / 运行时间）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`，
/// 用 `addEntries(_:)`（追加语义）注册入口，不覆盖其他插件贡献的入口。
@MainActor
public final class DevicePlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.device"
    public let order = 150

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

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
}
