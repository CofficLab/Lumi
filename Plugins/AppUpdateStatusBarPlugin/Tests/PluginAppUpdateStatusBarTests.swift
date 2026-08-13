import Foundation
import KernelLumi
import Testing
@testable import AppUpdateStatusBarPlugin

@MainActor
struct PluginAppUpdateStatusBarTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppUpdateStatusBarPlugin().id == "com.coffic.lumi.plugin.app-update-status-bar")
        #expect(AppUpdateStatusBarPlugin().name.isEmpty == false)
        #expect(AppUpdateStatusBarPlugin().category == .general)
        #expect(AppUpdateStatusBarPlugin().order == 8)
        #expect(AppUpdateStatusBarPlugin().policy == .alwaysOn)
    }

    @Test
    func menuBarContributionsAreProvided() {
        let context = LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        #expect(AppUpdateStatusBarPlugin.menuBarContentItems(context: context).count == 1)
        #expect(AppUpdateStatusBarPlugin.menuBarPopupItems(context: context).count == 1)
    }

    @Test
    func storeTracksPendingUpdateNotifications() async {
        let store = AppUpdateStatusBarStore.shared
        store.stop()
        store.start()

        NotificationCenter.default.post(
            name: .appUpdateReadyToInstall,
            object: nil,
            userInfo: ["version": "1.2.3"]
        )
        await Task.yield()

        #expect(store.pendingVersion == "1.2.3")
        #expect(store.hasPendingUpdate == true)

        store.installPreparedUpdate()
        await Task.yield()

        #expect(store.pendingVersion == nil)
        #expect(store.hasPendingUpdate == false)

        store.stop()
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginAppUpdateStatusBarLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(PluginAppUpdateStatusBarLocalization.string("App Update Status").isEmpty == false)
    }
}
