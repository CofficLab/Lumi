import KernelCore
import LumiUI
import ProviderToolbar
import SwiftUI

/// 工具栏 - 设置按钮插件
///
/// 在工具栏右侧注册一个设置按钮；点击发出「打开设置」通知，
/// 由宿主 App 监听并打开设置窗口。
///
/// 按钮样式与旧版 LumiApp（`SettingsPlugin.titleToolbarItems` 贡献的
/// `AppIconButton(systemImage: "gearshape")`）**完全一致**：直接复用
/// LumiUI 的 `AppIconButton`（默认 `.compact`：10pt 图标 + 6pt padding +
/// 圆角背景 + hover/按压反馈 + 缩放动画）。hover 提示由工具栏宿主
/// 统一按 `item.title` 提供（与旧版 `AppTitleToolbar` 一致）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `ToolbarProviding`，
/// 用 `addToolbarItems(_:)`（追加语义）注册按钮，不覆盖其他插件的贡献。
@MainActor
public final class SettingsToolbarPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.toolbar-settings"
    public let order = 200

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            // 工具栏未注册：优雅降级，不贡献按钮。
            return
        }

        let item = ToolbarItem(
            id: "settings",
            title: "设置",
            placement: .trailing,
            order: 100
        ) {
            AppIconButton(systemImage: "gearshape") {
                NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
            }
        }

        toolbar.addToolbarItems([item])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolbarProviding).self)?
            .removeToolbarItems(ids: ["settings"])
    }
}
