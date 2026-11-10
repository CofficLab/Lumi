import KernelCore
import SwiftUI
import Testing
@testable import ProviderMenuBar

@Suite("ProviderMenuBar")
@MainActor
struct ProviderMenuBarTests {
    private func contribution(
        _ id: String,
        order: Int = 200,
        owner: String = "plugin-a"
    ) -> MenuBarContribution {
        MenuBarContribution(id: id, title: id, order: order, ownerPluginID: owner) {
            Text(id)
        }
    }

    @Test("贡献按 order 和 id 排序且按 id 去重")
    func sortsAndDeduplicates() {
        let provider = DefaultMenuBarProviding()

        provider.addContent(contribution("b", order: 20))
        provider.addContent(contribution("a", order: 20))
        provider.addContent(contribution("first", order: 10))
        provider.addContent(contribution("a", order: 1, owner: "plugin-b"))

        #expect(provider.contentItems.map(\.id) == ["first", "a", "b"])
        #expect(provider.contentItems[1].ownerPluginID == "plugin-a")
    }

    @Test("按插件撤回不影响其他插件")
    func removesOnlyOwnedItems() {
        let provider = DefaultMenuBarProviding()
        provider.addContent(contribution("a-content"))
        provider.addPopup(contribution("a-popup"))
        provider.addContent(contribution("b-content", owner: "plugin-b"))
        provider.addPopup(contribution("b-popup", owner: "plugin-b"))

        provider.removeItems(ownedBy: "plugin-a")

        #expect(provider.contentItems.map(\.id) == ["b-content"])
        #expect(provider.popupItems.map(\.id) == ["b-popup"])
    }

    @Test("按 id 同时撤回常驻和弹窗贡献")
    func removesItemsByID() {
        let provider = DefaultMenuBarProviding()
        provider.addContent(contribution("shared"))
        provider.addPopup(contribution("shared"))
        provider.addPopup(contribution("other"))

        provider.removeItems(ids: ["shared"])

        #expect(provider.contentItems.isEmpty)
        #expect(provider.popupItems.map(\.id) == ["other"])
    }

    @Test("观察句柄可取消且重复取消安全")
    func observesAndCancels() {
        let provider = DefaultMenuBarProviding()
        var events: [MenuBarEvent] = []
        let observer = provider.addMenuBarObserver { events.append($0) }

        provider.addContent(contribution("content"))
        observer.cancel()
        observer.cancel()
        provider.addPopup(contribution("popup"))

        #expect(events.count == 1)
    }

    @Test("刷新模型桥接 Provider 事件")
    func refreshesSwiftUIModel() {
        let provider = DefaultMenuBarProviding()
        let model = MenuBarRefreshModel(provider: provider)

        provider.addContent(contribution("content"))
        #expect(model.revision == 1)

        model.cancel()
        provider.addPopup(contribution("popup"))
        #expect(model.revision == 1)
    }

    @Test("Kernel 自动撤回并恢复共享插件贡献")
    func kernelOwnsContributionLifecycle() async throws {
        let kernel = KernelCoreContainer()
        let provider = DefaultMenuBarProviding()
        try kernel.registerHostProvider(MenuBarProviding.self, provider)
        let plugin = TestMenuBarPlugin()
        try kernel.start(plugins: [plugin])

        #expect(provider.contentItems.map(\.id) == ["test.content"])
        #expect(provider.popupItems.map(\.id) == ["test.popup"])

        try await kernel.disablePlugin(id: plugin.id)
        #expect(provider.contentItems.isEmpty)
        #expect(provider.popupItems.isEmpty)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(provider.contentItems.map(\.id) == ["test.content"])
        #expect(provider.popupItems.map(\.id) == ["test.popup"])

        try await kernel.unloadPluginAsync(id: plugin.id)
        #expect(provider.contentItems.isEmpty)
        #expect(provider.popupItems.isEmpty)
    }
}

@MainActor
private final class TestMenuBarPlugin: SuperPlugin {
    let id = "test-menu-bar"
    let metadata = PluginMetadata(
        id: "test-menu-bar",
        name: "Test Menu Bar",
        description: "Tests shared menu bar contributions",
        policy: .enabledByDefault
    )

    func onBoot(kernel: KernelCoreContainer) throws {
        try contribute(to: kernel)
    }

    func onEnable(kernel: KernelCoreContainer) async throws {
        try contribute(to: kernel)
    }

    private func contribute(to kernel: KernelCoreContainer) throws {
        let menuBar = try kernel.requireProvider(MenuBarProviding.self)
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addContent(MenuBarContribution(
            id: "test.content",
            title: "Content",
            ownerPluginID: id
        ) {
            Text("Content")
        })
        menuBar.addPopup(MenuBarContribution(
            id: "test.popup",
            title: "Popup",
            ownerPluginID: id
        ) {
            Text("Popup")
        })
    }
}
