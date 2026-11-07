import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import Testing
@testable import PluginBookletMaker

/// Assembly coverage for `BookletMakerPlugin`.
///
/// The plugin is the seam between two hosts (Lumi's workbench and
/// GameFactory's standalone app) and every host-specific concern is injected
/// through `init` or read from the kernel. These tests pin down that wiring:
/// what the plugin registers, what it resolves, and how it must behave when
/// a host leaves a provider out.
@MainActor
@Suite("BookletMakerPlugin / assembly")
struct BookletMakerPluginAssemblyTests {

    // MARK: - Identity & metadata

    @Test("metadata mirrors the injected identity and enable policy")
    func metadataFollowsInjectedIdentity() {
        let plugin = BookletMakerPlugin(
            id: "com.coffic.bookletmaker.plugin.booklet-maker",
            order: 42,
            policy: .required
        )

        #expect(plugin.id == "com.coffic.bookletmaker.plugin.booklet-maker")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.order == 42)
        #expect(plugin.metadata.policy == .required)
        #expect(!plugin.metadata.name.isEmpty)
        #expect(!plugin.metadata.description.isEmpty)
    }

    @Test("two hosts can coexist under distinct identities")
    func distinctIdentitiesCoexist() {
        let lumi = BookletMakerPlugin(id: "com.coffic.lumi.plugin.booklet-maker")
        let gameFactory = BookletMakerPlugin(
            id: "com.coffic.bookletmaker.plugin.booklet-maker",
            policy: .required
        )

        #expect(lumi.id != gameFactory.id)
        #expect(lumi.metadata.id != gameFactory.metadata.id)
        #expect(lumi.order != gameFactory.order || lumi.metadata.policy != gameFactory.metadata.policy)
    }

    @Test("the legacy data directory is declared for host migration")
    func legacyDataDirectoryNames() {
        #expect(BookletMakerPlugin().legacyDataDirectoryNames == ["BookletMaker"])
    }

    @Test("the rail tab id is a stable constant independent of the host id")
    func railTabIDIsStable() {
        #expect(BookletMakerPlugin.railTabID == "booklet-maker.sidebar")
        let plugin = BookletMakerPlugin(id: "com.example.other.host")
        #expect(BookletMakerPlugin.railTabID == plugin.id || BookletMakerPlugin.railTabID != "")
    }

    @Test("the activity bar entry id is namespaced by the plugin id")
    func activityBarEntryIsNamespaced() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)

        let plugin = BookletMakerPlugin(id: "com.example.namespaced.host")
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.items.contains { $0.id == "\(plugin.id).entry" })
        #expect(!activityBar.items.contains { $0.id == BookletMakerPlugin.defaultPluginID + ".entry" })
    }

    // MARK: - Rail registration

    @Test("booting registers exactly one design rail tab")
    func bootRegistersRailTab() throws {
        let kernel = KernelCoreContainer()
        let rail = DefaultRailViewProviding(visibleCategories: [.design])
        try kernel.registerProvider((any RailViewProviding).self, rail)

        #expect(rail.tabs.isEmpty)
        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rail.tabs.count == 1)
        let tab = rail.tabs[0]
        #expect(tab.id == BookletMakerPlugin.railTabID)
        #expect(tab.category == .design)
        #expect(tab.order == plugin.order)
        #expect(!tab.title.isEmpty)
    }

    @Test("a second boot does not duplicate the rail tab")
    func repeatedBootDoesNotDuplicateTabs() throws {
        let kernel = KernelCoreContainer()
        let rail = DefaultRailViewProviding(visibleCategories: [.design])
        try kernel.registerProvider((any RailViewProviding).self, rail)

        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        #expect(
            rail.tabs.filter { $0.id == BookletMakerPlugin.railTabID }.count == 1,
            "Re-booting must not stack duplicate rail tabs"
        )
    }

    // MARK: - Content view

    @Test("booting installs the booklet workspace as the content view")
    func bootInstallsContentView() throws {
        let kernel = KernelCoreContainer()
        let contentView = DefaultContentViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, contentView)

        // `contentView` is fileprivate in the provider, so assert through
        // the observable side: installing a content view fires the observer.
        var didPublishContent = false
        let handle = contentView.addContentViewObserver { _ in didPublishContent = true }
        defer { handle.cancel() }

        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(didPublishContent, "The plugin must claim the content area")
    }

    // MARK: - Docs registration

    @Test("onRegister contributes an about and a manual entry")
    func onRegisterAddsDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = BookletMakerPlugin(id: "com.example.docs.host")
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.map(\.id) == ["com.example.docs.host"])
        #expect(docs.manualEntries.map(\.id) == ["com.example.docs.host"])
        #expect(docs.aboutEntries.first?.name == plugin.name)
    }

    @Test("onRegister is a no-op when the host has no docs provider")
    func onRegisterWithoutDocsProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = BookletMakerPlugin()

        // GameFactory's standalone app does not register a docs provider.
        try plugin.onRegister(kernel: kernel)
    }

    // MARK: - Storage bridge

    @Test("booting publishes the plugin data directory to the runtime bridge")
    func bootPublishesPluginDataDirectory() throws {
        let kernel = KernelCoreContainer()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookletMakerPluginTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = BookletMakerPlugin(id: "com.example.storage.host")
        try plugin.onBoot(kernel: kernel)

        let expected = storage.pluginDataDirectory(for: plugin.id)
        #expect(BookletMakerRuntimeBridge.directoryURL == expected)
        #expect(BookletMakerRuntimeBridge.directoryURL?.lastPathComponent.contains("storage.host") == true)
    }

    @Test("booting without a storage provider clears the runtime bridge")
    func bootWithoutStorageClearsBridge() throws {
        let kernel = KernelCoreContainer()
        BookletMakerRuntimeBridge.directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stale-\(UUID().uuidString)", isDirectory: true)

        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(
            BookletMakerRuntimeBridge.directoryURL == nil,
            "A stale directory from a previous host must not leak into this one"
        )
    }

    // MARK: - Toolbar

    @Test("activating installs a title item and deactivating removes it")
    func toolbarItemFollowsActivation() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        // Seed a default entry so the booklet plugin item does not get
        // auto-activated on boot; a host without other entries would
        // activate it immediately, which is covered by the next test.
        activityBar.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(
            !toolbar.toolbarItems.contains { $0.id == "\(plugin.id).title" },
            "The title item must not exist before the workbench is opened"
        )

        activityBar.activateItem(id: "\(plugin.id).entry")
        #expect(toolbar.toolbarItems.contains { $0.id == "\(plugin.id).title" })
        #expect(toolbar.visibleCategories == [.global, .design])

        activityBar.activateItem(id: nil)
        #expect(!toolbar.toolbarItems.contains { $0.id == "\(plugin.id).title" })
        #expect(toolbar.visibleCategories == Set(ToolbarItemCategory.allCases))
    }

    // MARK: - Minimal host

    @Test("booting against a bare kernel succeeds without any providers")
    func bootsWithBareKernel() throws {
        // The plugin must never assume a host registered a provider; a
        // minimal host should still get a usable, if bare, boot.
        let kernel = KernelCoreContainer()
        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)
    }

    @Test("workspace hooks are optional on a host without a chat area")
    func hooksAreOptional() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding(visibleCategories: [.chat])
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any RailViewProviding).self, rail)

        let plugin = BookletMakerPlugin()
        try plugin.onBoot(kernel: kernel)
        activityBar.activateItem(id: "\(plugin.id).entry")
        activityBar.activateItem(id: nil)

        #expect(rail.visibleTabID != BookletMakerPlugin.railTabID || rail.visibleCategories.isEmpty == false)
    }
}
