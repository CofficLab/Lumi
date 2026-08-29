import Testing
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
import ProviderRootView
@testable import PluginDiskManager

@MainActor
struct PluginDiskManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DiskManagerPlugin().id == "com.coffic.lumi.plugin.disk-manager")
        #expect(DiskManagerPlugin().name.isEmpty == false)
        #expect(DiskManagerPlugin().order == 250)
        #expect(DiskManagerPlugin().metadata.policy == .disabledByDefault)
        #expect(DiskManagerPlugin().metadata.stage == .stable)
    }

    @Test
    func agentToolsContributionIsAvailable() {
        #expect(DiskManagerPlugin.agentTools.count == 10)
        #expect(DiskManagerPlugin.agentTools.allSatisfy { !$0.name.isEmpty })
    }

    @Test
    func railTabIDIsStable() {
        #expect(DiskManagerPlugin.railTabID == "com.coffic.lumi.plugin.disk-manager.categories")
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rail = DefaultRailViewProviding(visibleCategories: [.chat])
        let root = DefaultRootViewProvider()
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any RootViewProviding).self, root)

        activity.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])

        try DiskManagerPlugin().onBoot(kernel: kernel)

        #expect(activity.activeItemID == "chat.entry")

        activity.activateItem(id: "com.coffic.lumi.plugin.disk-manager.entry")

        #expect(!chat.isVisible)
        #expect(rail.visibleCategories == [.system])
        #expect(rail.visibleTabID == DiskManagerPlugin.railTabID)
        #expect(rail.activeTabID == DiskManagerPlugin.railTabID)
        #expect(root.isContentHeaderViewHidden)

        activity.activateItem(id: nil)

        #expect(chat.isVisible)
        #expect(rail.visibleCategories == Set(RailViewCategory.allCases))
        #expect(root.isContentHeaderViewHidden == false)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDiskManagerLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(PluginDiskManagerLocalization.string("Disk Manager").isEmpty == false)
    }

    @Test
    func scanURLAcceptsUnescapedFileURL() {
        #expect(
            DiskManagerViewModel.scanURL(from: "file:///tmp/project/My Folder").path
                == "/tmp/project/My Folder"
        )
    }

    @Test
    func scanURLAcceptsLocalPathAndTilde() {
        #expect(DiskManagerViewModel.scanURL(from: " /tmp/project ").path == "/tmp/project")
        #expect(
            DiskManagerViewModel.scanURL(from: "~/Downloads").path
                == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        )
    }
}
