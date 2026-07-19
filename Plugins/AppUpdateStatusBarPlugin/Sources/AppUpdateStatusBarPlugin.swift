import LumiKernel
import SwiftUI

public enum AppUpdateStatusBarPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-update-status-bar",
        displayName: PluginAppUpdateStatusBarLocalization.string("App Update Status"),
        description: PluginAppUpdateStatusBarLocalization.string("Shows a menu bar reminder when an app update is ready to install."),
        order: 8,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.down.circle",
    )

    @MainActor
    public static func menuBarContentItems(context: any LumiCoreAccessing) -> [LumiMenuBarContentItem] {
        AppUpdateStatusBarStore.shared.start()
        return [
            LumiMenuBarContentItem(id: "\(info.id).content", order: info.order) {
                AppUpdateStatusBarContentView(store: AppUpdateStatusBarStore.shared)
            }
        ]
    }

    @MainActor
    public static func menuBarPopupItems(context: any LumiCoreAccessing) -> [LumiMenuBarPopupItem] {
        AppUpdateStatusBarStore.shared.start()
        return [
            LumiMenuBarPopupItem(id: "\(info.id).popup", order: info.order) {
                AppUpdateStatusBarPopupView(store: AppUpdateStatusBarStore.shared)
            }
        ]
    }
}

enum PluginAppUpdateStatusBarLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
