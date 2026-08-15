import KernelCore
import ProviderToolbar
import SwiftUI

/// 工具栏 - 设置按钮插件
///
/// 在工具栏右侧注册一个设置按钮；点击发出「打开设置」通知，
/// 由宿主 App 监听并打开设置窗口。
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
            SettingsToolbarButtonView()
        }

        toolbar.addToolbarItems([item])
    }
}

/// 设置按钮视图：点击发出「打开设置」通知。
private struct SettingsToolbarButtonView: View {
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("设置")
    }
}
