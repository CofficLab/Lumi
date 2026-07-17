import LumiCoreKit
import LumiUI
import SwiftUI
import Foundation

public enum DeviceInfoPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.device-info",
        displayName: LumiPluginLocalization.string("Device Info", bundle: .module),
        description: LumiPluginLocalization.string("Shows basic device and system information.", bundle: .module),
        order: 2,
        category: .system,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "macbook.and.iphone",
    )


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
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "cpu",
                            title: LumiPluginLocalization.string("System metrics", bundle: .module),
                            description: LumiPluginLocalization.string("CPU, memory, and uptime at a glance", bundle: .module)
                        ),
                        .init(
                            icon: "menubar.rectangle",
                            title: LumiPluginLocalization.string("Menu bar", bundle: .module),
                            description: LumiPluginLocalization.string("Live metrics in the menu bar", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Device Info from the sidebar to see full details.", bundle: .module)
                )
            )
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
