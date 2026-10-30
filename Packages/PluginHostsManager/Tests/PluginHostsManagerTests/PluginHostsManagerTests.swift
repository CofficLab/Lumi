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
        // `.xcstrings` 是**源**目录里的文件；SPM 打包时会被编译成各语言的
        // `Localizable.strings`（`<lang>.lproj/Localizable.strings`），
        // 原始 `.xcstrings` 不会进 bundle。只查 `.xcstrings` 恒为 nil。
        let hasCatalog = bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
        #expect(PluginHostsManager.pluginLocalization.string("Hosts Manager").isEmpty == false)
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let contentView = DefaultContentViewProviding()
        let railView = DefaultRailViewProviding()
        let rootView = DefaultRootViewProviding()
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
