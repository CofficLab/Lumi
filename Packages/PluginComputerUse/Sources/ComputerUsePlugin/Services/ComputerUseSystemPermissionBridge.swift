import Foundation
import ProviderSettingView

/// 打开 Lumi 设置的 Computer Use 入口。
///
/// 设置窗口由宿主 App 持有，插件只能通过 `SettingViewNavigation` 的通知
/// 表达「打开设置并选中某个入口」的意图，窗口的打开与选中由宿主处理。
/// 这样插件不需要依赖宿主实现。
///
/// - Note: 通知名在进程内有效，同名即可互通（与 `PluginActivityBar` 的做法一致）。
@MainActor
final class ComputerUseSystemPermissionBridge {
    static let shared = ComputerUseSystemPermissionBridge()

    /// Computer Use 在设置侧边栏中的入口 ID。
    ///
    /// 与插件入口注册 `SettingEntryItem` 时使用的 ID 保持一致。
    static var settingsEntryID: String { ComputerUsePlugin.settingsEntryID }

    private init() {}

    /// 打开 Lumi 设置并选中 Computer Use 入口。
    func openLumiSettings() {
        NotificationCenter.default.post(
            name: SettingViewNavigation.openSettingsNotification,
            object: nil,
            userInfo: [SettingViewNavigation.entryIDUserInfoKey: Self.settingsEntryID]
        )
    }
}
