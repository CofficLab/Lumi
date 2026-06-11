import LumiCoreKit
import Foundation

public enum DeviceInfoPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.device-info",
        displayName: String(localized: "Device Info", bundle: .module),
        description: String(localized: "Shows basic device and system information.", bundle: .module),
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
            },
            LumiMenuBarPopupItem(id: "\(info.id).gpu", order: info.order + 2) {
                GPUMenuBarPopupView()
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
