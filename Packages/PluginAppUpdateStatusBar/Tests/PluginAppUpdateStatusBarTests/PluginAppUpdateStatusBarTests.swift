import Foundation
import Testing
import LumiCoreKit
@testable import PluginAppUpdateStatusBar

@MainActor
struct PluginAppUpdateStatusBarTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppUpdateStatusBarPlugin.id == "AppUpdateStatusBar")
        #expect(AppUpdateStatusBarPlugin.navigationId == "app_update_status_bar")
        #expect(AppUpdateStatusBarPlugin.displayName.isEmpty == false)
        #expect(AppUpdateStatusBarPlugin.description.isEmpty == false)
        #expect(AppUpdateStatusBarPlugin.iconName == "arrow.down.circle")
        #expect(AppUpdateStatusBarPlugin.isConfigurable == false)
        #expect(AppUpdateStatusBarPlugin.category == .general)
        #expect(AppUpdateStatusBarPlugin.order == 8)
        #expect(AppUpdateStatusBarPlugin.enable == true)
        #expect(AppUpdateStatusBarPlugin.shared.instanceLabel == AppUpdateStatusBarPlugin.id)
    }

    @Test
    func menuBarContributionsAreProvided() {
        #expect(AppUpdateStatusBarPlugin.shared.addMenuBarContentView() != nil)
        #expect(AppUpdateStatusBarPlugin.shared.addMenuBarPopupView() != nil)
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
        #expect(PluginAppUpdateStatusBarLocalization.bundle.url(forResource: "AppUpdateStatusBar", withExtension: "xcstrings") != nil)
        #expect(PluginAppUpdateStatusBarLocalization.string("App Update Status").isEmpty == false)
    }
}
