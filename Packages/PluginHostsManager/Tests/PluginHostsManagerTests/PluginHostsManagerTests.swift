import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import Testing
import Foundation
@testable import PluginHostsManager

@MainActor
struct PluginHostsManagerTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = HostsManagerPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.hosts-manager")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 21)
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(PluginHostsManager.LumiPluginLocalization.string("Hosts Manager", bundle: .module).isEmpty == false)
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let contentView = DefaultContentViewProviding()
        let railView = DefaultRailViewProviding()
        let rootView = DefaultRootViewProvider()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = HostsManagerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.activeItemID == "\(plugin.id).entry")
        #expect(!chat.isVisible)

        activityBar.activateItem(id: nil)

        #expect(chat.isVisible)
        #expect(rootView.isContentHeaderViewHidden == false)

        try plugin.onShutdown(kernel: kernel)
    }
}
