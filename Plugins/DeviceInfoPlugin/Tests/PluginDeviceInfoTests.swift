import Foundation
import Testing
import LumiCoreKit
@testable import DeviceInfoPlugin

@MainActor
struct PluginDeviceInfoTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DeviceInfoPlugin.info.id == "com.coffic.lumi.plugin.device-info")
        #expect(DeviceInfoPlugin.info.displayName.isEmpty == false)
        #expect(DeviceInfoPlugin.info.description.isEmpty == false)
        #expect(DeviceInfoPlugin.iconName == "macbook.and.iphone")
        #expect(DeviceInfoPlugin.info.order == 0)
    }

    @Test
    func pluginPolicyIsAlwaysOn() {
        #expect(DeviceInfoPlugin.policy == .alwaysOn)
    }

    @Test
    func pluginCategoryIsSystem() {
        #expect(DeviceInfoPlugin.category == .system)
    }

    @Test
    func viewContainerIsProvided() {
        let items = DeviceInfoPlugin.viewContainers(
            context: LumiPluginContext(
                activeSectionID: "workspace",
                activeSectionTitle: "Workspace"
            )
        )

        #expect(items.count == 1)
        #expect(items.first?.id == DeviceInfoPlugin.info.id)
        #expect(items.first?.title == DeviceInfoPlugin.info.displayName)
        #expect(items.first?.systemImage == DeviceInfoPlugin.iconName)
    }

    @Test
    func onboardingPageIsProvided() {
        let pages = DeviceInfoPlugin.onboardingPages(
            context: LumiPluginContext(
                activeSectionID: "workspace",
                activeSectionTitle: "Workspace"
            )
        )

        #expect(pages.count == 1)
        #expect(pages.first?.id == "\(DeviceInfoPlugin.info.id).onboarding")
        #expect(pages.first?.order == DeviceInfoPlugin.info.order)
    }

    @Test
    func menuBarContentItemsProvided() {
        let items = DeviceInfoPlugin.menuBarContentItems(
            context: LumiPluginContext(
                activeSectionID: "workspace",
                activeSectionTitle: "Workspace"
            )
        )
        #expect(items.count == 1)
        #expect(items.first?.id == "\(DeviceInfoPlugin.info.id).metrics")
    }

    @Test
    func menuBarPopupItemsProvided() {
        let items = DeviceInfoPlugin.menuBarPopupItems(
            context: LumiPluginContext(
                activeSectionID: "workspace",
                activeSectionTitle: "Workspace"
            )
        )
        #expect(items.count == 3)
        #expect(items[0].id == "\(DeviceInfoPlugin.info.id).cpu")
        #expect(items[1].id == "\(DeviceInfoPlugin.info.id).memory")
        #expect(items[2].id == "\(DeviceInfoPlugin.info.id).gpu")
    }
}
