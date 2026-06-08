import LumiCoreKit
import Foundation

public enum DeviceInfoPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.device-info",
        displayName: "Device Info",
        description: "Shows basic device and system information.",
        order: 20
    )
    public static let category: LumiPluginCategory = .system
    public static let policy: LumiPluginPolicy = .optIn

    public static let iconName = "macbook.and.iphone"

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DeviceInfoView()
            }
        ]
    }

    @MainActor
    public static func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        [
            LumiMenuBarContentItem(id: "\(info.id).metrics", order: info.order) {
                DeviceInfoMenuBarContentView()
            }
        ]
    }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).cpu", order: info.order) {
                DeviceInfoMenuBarPopupView()
            },
            LumiMenuBarPopupItem(id: "\(info.id).memory", order: info.order + 1) {
                MemoryMenuBarPopupView()
            }
        ]
    }
}

enum PluginDeviceInfoLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
